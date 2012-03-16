/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.File;
import java.io.InputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;

import javax.servlet.ServletInputStream;

/**
 * Originally inspired by Kirk's RewindableInputStream ...
 * but otherwise a completely re-mastered rewinding beast.
 * 
 * @author kares
 */
public class RewindableInputStream extends ServletInputStream {
    
    /**
     * Initial (default) buffer size for a new stream.
     */
    public static final int INI_BUFFER_SIZE = 4096;
    
    /**
     * Maximum buffer size before content is buffered into a temporary file.
     */
    public static final int MAX_BUFFER_SIZE = 4 * 4096;
    
    private static final int TMP_READ_BUFFER_SIZE = 1024;
    
    public static final String TMP_FILE_PREFIX = "jruby-rack-input_";
    
    private static int iniBufferSize = INI_BUFFER_SIZE;

    public static int getDefaultInitialBufferSize() {
        return iniBufferSize;
    }

    /**
     * Set the (default) initial buffer size for all instances created using
     * {@link #RewindableInputStream(java.io.InputStream)}.
     * @param iniBufferSize 
     */
    public static void setDefaultInitialBufferSize(int iniBufferSize) {
        RewindableInputStream.iniBufferSize = iniBufferSize;
    }
    
    private static int maxBufferSize = MAX_BUFFER_SIZE;

    public static int getDefaultMaximumBufferSize() {
        return maxBufferSize;
    }

    /**
     * Set the (default) maximum buffer size for all instances created using
     * {@link #RewindableInputStream(java.io.InputStream)}.
     * @param maxBufferSize 
     */
    public static void setDefaultMaximumBufferSize(int maxBufferSize) {
        RewindableInputStream.maxBufferSize = maxBufferSize;
    }
    
    private final InputStream input;
    
    // an in memory buffer, the wrapped stream will be buffered in memory 
    // until this buffer is full, then it will be written to a temp file.
    // we're using the buffer.limit() to track how many bytes are currently 
    // left in the buffer
    private ByteBuffer buffer;
    private final int bufferMax;
    
    // the on disk buffered content for this stream
    private RandomAccessFile bufferFile = null;
    private String bufferFilePath; // file path (for deletion)

    // last remembered position (mark support)
    private long mark = -1;
    
    /**
     * Wrap an input stream to be king and rewind ...
     * @param input 
     */
    public RewindableInputStream(InputStream input) {
        this(input, iniBufferSize, maxBufferSize);
    }

    /**
     * Wrap an input stream to be king and rewind ...
     * @param input 
     * @param bufferSize the buffer size
     */
    public RewindableInputStream(InputStream input, int bufferSize) {
        this(input, bufferSize, bufferSize);
    }

    /**
     * Wrap an input stream to be king and rewind ...
     * @param input 
     * @param iniBufferSize initial buffer size
     * @param maxBufferSize maximum buffer size (when reached content gets written into a file)
     */
    public RewindableInputStream(InputStream input, int iniBufferSize, int maxBufferSize) {
        this.input = input; // super(input);
        this.buffer = ByteBuffer.allocate(iniBufferSize);
        this.buffer.limit(0); // empty
        this.bufferMax = maxBufferSize;
    }

    /**
     * @see InputStream#available() 
     */
    @Override
    public synchronized int available() throws IOException {
        ensureOpen();
        return input.available() + buffer.remaining();
    }

    /**
     * @see InputStream#markSupported() 
     */
    @Override
    public boolean markSupported() {
        return true;
    }

    /**
     * @see InputStream#mark(int) 
     */
    @Override
    public synchronized void mark(int readlimit) {
        try {
            this.mark = getPosition(); //this.position;
            // to keep it simple we ensure there's enough
            // room left in the buffer itself :
            assureBufferCapacity(readlimit, true);
        }
        catch (IOException e) {
            // should not happen since we're forcing
            throw new IllegalStateException(e);
        }
    }

    /**
     * @see InputStream#reset() 
     */
    @Override
    public synchronized void reset() throws IOException {
        ensureOpen();
        
        if (this.mark < 0) {
            throw new IOException("The marked position is invalid");
        }
        setPosition(this.mark);
    }
    
    /**
     * @see InputStream#read() 
     */    
    @Override
    public synchronized int read() throws IOException {
        ensureOpen();
        
        if (fillBuffer(1) == -1) return -1;  // EOF
        
        //this.position++; // track stream position
        return this.buffer.get() & 0xFF;
    }

    /**
     * @see InputStream#read(byte[], int, int) 
     */
    @Override
    public synchronized int read(byte[] buffer, final int offset, final int length) 
        throws IOException {
        ensureOpen();

        int count = 0;
        while (count < length) {
            final int len = fillBuffer(length - count);
            if (len == -1) return count == 0 ? -1 : count; // EOF

            //this.position += len; // track stream position
            this.buffer.get(buffer, offset + count, len);
            count += len;
        }

        return count;
    }

    /**
     * @see InputStream#close() 
     */
    @Override
    public synchronized void close() throws IOException {
        if (buffer == null) return;

        if (bufferFile != null) {
            try {
                bufferFile.close();
            }
            finally {
                new File(bufferFilePath).delete();
            }
        }

        super.close();
        buffer = null;
    }
    
    /**
     * Rewind this stream (kindly) to the start.
     * @throws IOException 
     */
    public synchronized void rewind() throws IOException {
        ensureOpen();
        setPosition(0);
    }

    private void ensureOpen() throws IOException {
        if (buffer == null) {
            throw new IOException("IO is closed");
        }
    }

    /**
     * Fill the buffer from the underlying stream with count bytes.
     * @param count
     * @return the number of bytes filled (might be less than count)
     * @throws IOException 
     */
    private int fillBuffer(final int count) throws IOException {
        if ( ! isFileBuffered() ) {
            assureBufferCapacity(count, false); // might switch to file
        }
        // isFileBuffered() might have changed with assureBufferCapacity
        if ( isFileBuffered() ) {
            return fillBufferFromFile(count);
        }
        else {
            if ( ! buffer.hasArray() ) {
                throw new IllegalStateException("byte buffer without backing array");
            }
            
            // make sure count bytes available in buffer (unless EOF reached)
            while ( buffer.remaining() < count ) {
                int read = count - buffer.remaining();
                // read into buffer from the underlying stream :
                read = input.read(buffer.array(), buffer.limit(), read);
                if ( read == -1 ) { 
                    if ( buffer.remaining() == 0 ) return -1;
                    else break;
                }
                buffer.limit(buffer.limit() + read);
            }
            
            return Math.min(buffer.remaining(), count);
        }
    }
    
    private void assureBufferCapacity(int count, boolean force) throws IOException {
        if ( buffer.position() + count > buffer.capacity() ) {
            // we'll try to incrementaly increase the buffer capacity :
            int newSize = buffer.capacity() + Math.max(count, buffer.capacity());
            if (newSize <= bufferMax) {
                buffer = copyBuffer(newSize);
            }
            // forcing is not really used - only here to ease mark() support
            else if (force) {
                newSize = buffer.capacity() + count;
                buffer = copyBuffer(newSize);
            }
            else {
                setFileBuffered();
            }
        }
    }
    
    /**
     * Allocate a new buffer with the specified capacity and content from the 
     * current buffer.
     * @param capacity
     * @return a new buffer (copy of current)
     */
    private ByteBuffer copyBuffer(final int capacity) {
        ByteBuffer newBuffer = ByteBuffer.allocate(capacity);
        if ( ! buffer.hasArray() || ! newBuffer.hasArray() ) {
            throw new IllegalStateException("byte buffer without backing array");
        }
        newBuffer.position(buffer.position());
        newBuffer.limit(buffer.limit());
        System.arraycopy(
                buffer.array(), buffer.arrayOffset(), 
                newBuffer.array(), newBuffer.arrayOffset(), 
                buffer.limit()
        );
        return newBuffer;
    }

    private int fillBufferFromFile(final int count) throws IOException {
        if ( buffer.remaining() < count ) { // need to fill in buffer
            int read = count - buffer.remaining();
            
            final long position = bufferFile.getFilePointer();
            while ( bufferFile.length() - position < read ) { // mostly an if
                // attempt to fill in from underlying stream :
                final byte[] data = new byte[TMP_READ_BUFFER_SIZE];
                final int dataLen = input.read(data);
                
                if ( dataLen != -1 ) {
                    bufferFile.seek(bufferFile.length());
                    bufferFile.write(data, 0, dataLen);
                    bufferFile.seek(position); // read from where we left   
                }
                else {
                    break; // no more data to read from stream
                }
            }

            if ( buffer.limit() + count > buffer.capacity() && buffer.position() > 0 ) {
                if ( ! buffer.hasArray() ) {
                    throw new IllegalStateException("byte buffer without backing array");
                }
                // reset the buffer array to 0 but keep the data not yet read :
                System.arraycopy(
                        buffer.array(), buffer.position(), 
                        buffer.array(), 0, 
                        buffer.remaining() // length = limit - position
                );
                buffer.limit(buffer.remaining()).position(0);
            }
            
            // finally fill buffer from underlying file as much as possible
            final int free = buffer.capacity() - buffer.limit();
            read = bufferFile.read(buffer.array(), buffer.limit(), free);
            if ( read == -1 && buffer.remaining() == 0 ) return -1;
            if ( read != -1 ) buffer.limit(buffer.limit() + read);
        }

        return Math.min(buffer.remaining(), count);
    }

    boolean isFileBuffered() {
        return this.bufferFile != null;
    }

    void setFileBuffered() throws IOException {
        if ( isFileBuffered() ) {
            throw new IllegalStateException("already buffered to a file");
        }
        
        final int position = this.buffer.position();
        
        File tmpFile = File.createTempFile(TMP_FILE_PREFIX, "");
        this.bufferFile = new RandomAccessFile(tmpFile, "rw");
        this.bufferFilePath = tmpFile.getPath();
        
        this.buffer.position(this.buffer.arrayOffset());
        this.bufferFile.getChannel().write(this.buffer);
        
        setPosition(position);
    }
    
    /**
     * NOTE: this assumes position less than of equal than the amount read from 
     * the stream (a.k.a. does not support traveling to the unknown future) !
     * 
     * @param position
     * @throws IOException 
     */
    private void setPosition(final long position) throws IOException {
        if ( isFileBuffered() ) {
            this.buffer.rewind().limit(0); // buffer.remaining() == 0
            this.bufferFile.seek(position);
        }
        else {
            this.buffer.rewind().position((int) position);
        }
        //this.position = position;
    }
    
    long getPosition() throws IOException {
        if ( isFileBuffered() ) {
            return bufferFile.getFilePointer();
        }
        else {
            return this.buffer.position();
        }        
    }

    public int getCurrentBufferSize() {
        return buffer.capacity();
    }
    
    public int getMaximumBufferSize() {
        return bufferMax;
    }
    
}
