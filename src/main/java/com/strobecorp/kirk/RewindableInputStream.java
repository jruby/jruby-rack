// Temporarily borrowed from Kirk
package com.strobecorp.kirk;

import java.io.File;
import java.io.FilterInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.RandomAccessFile;

import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;

// Special jruby specific methods
//import org.jruby.RubyString;

public class RewindableInputStream extends FilterInputStream {
  // The default buffer size
  public static final int DEFAULT_BUFFER_SIZE = 8192;

  // The tmp files prefix
  public static final String TMPFILE_PREFIX = "kirk-rewindable-input";

  // The tmp file's suffix
  public static final String TMPFILE_SUFFIX = "";

  // The in memory buffer, the wrapped stream will be buffered
  // in memory until this buffer is full, then it will be written
  // to a temp file.
  private ByteBuffer buf;

  // The wrapped stream converted to a Channel
  private ReadableByteChannel io;

  // The total number of bytes buffered
  private long buffered;

  // The current position within the stream
  private long position;

  // The last remembered position
  private long mark;

  // The on disk stream buffer
  private FileChannel tmpFile;

  public RewindableInputStream(InputStream io) {
    this(io, DEFAULT_BUFFER_SIZE);
  }

  public RewindableInputStream(InputStream io, int bufSize) {
    this(io, ByteBuffer.allocate(bufSize));
  }

  public RewindableInputStream(InputStream io, ByteBuffer buf) {
    super(io);

    this.buffered = 0;
    this.position = 0;
    this.mark     = -1;

    this.io  = Channels.newChannel(io);
    this.buf = buf;
  }

  public long getPosition() {
    return position;
  }

  public InputStream getUnbufferedInputStream() {
    return in;
  }

  @Override
  public synchronized int available() throws IOException {
    long available = buffered - position;

    ensureOpen();

    if ( available > Integer.MAX_VALUE ) {
      available = Integer.MAX_VALUE;
    }
    else if ( available < 0 ) {
      throw new IOException("Somehow the stream travelled to the future :(");
    }

    return (int) available;
  }

  @Override
  public synchronized void close() throws IOException {
    if ( buf == null ) {
      return;
    }

    if ( tmpFile != null ) {
      tmpFile.close();
    }

    io.close();
    buf = null;
  }

  @Override
  public synchronized void mark(int readlimit) {
    this.mark = this.position;
  }

  @Override
  public boolean markSupported() {
    return true;
  }

  @Override
  public synchronized int read() throws IOException {
    long len;

    ensureOpen();

    while ( true ) {
      len = fillBuf(1);

      if ( len == -1 ) {
        return -1;
      }
      else if ( len == 1 ) {
        return buf.get();
      }

      throw new IOException("WTF mate");
    }
  }

  @Override
  public synchronized int read(byte[] buffer, int offset, int length) throws IOException {
    int count = 0;
    int len;

    ensureOpen();

    while ( count < length ) {
      // Fill the buffer
      len = (int) fillBuf(length - count);

      // Handle EOFs
      if ( len == -1 ) {
        if ( count == 0 ) {
          return -1;
        }

        return count;
      }

      buf.get(buffer, offset + count, len);
      position += len;
      count    += len;
    }

    return count;
  }

  public byte[] read(int length) throws IOException {
    byte[] bytes = new byte[length];
    int len = read(bytes, 0, length);

    if ( len == -1 ) {
      return null;
    }
    else if ( len != length ) {
      byte[] sized = new byte[len];
      System.arraycopy(bytes, 0, sized, 0, len);
      bytes = sized;
    }

    return bytes;
  }

  // public synchronized int readAndAppendTo(RubyString str, int length) throws IOException {
  //   byte[] bytes = new byte[length];
  //   int len = read(bytes, 0, length);

  //   if ( len > 0 ) {
  //     str.getByteList().append(bytes, 0, len);
  //   }

  //   return len;
  // }

  @Override
  public synchronized void reset() throws IOException {
    if ( mark < 0 ) {
      throw new IOException("The marked position is invalid");
    }

    position = mark;
  }

  // XXX This is completely busted ;-)
  @Override
  public synchronized long skip(long amount) throws IOException {
    long count = 0;
    long len;

    ensureOpen();

    while ( amount > count ) {
      len = fillBuf(amount - count);

      if ( len == -1 ) {
        break;
      }

      count += len;
    }

    return count;
  }

  public synchronized void seek(long newPosition) throws IOException {
    ensureOpen();

    if ( newPosition < 0 ) {
      throw new IOException("Cannot seek to a negative position");
    }

    this.position = newPosition;
  }

  public synchronized void rewind() throws IOException {
    seek(0);
  }

  private void ensureOpen() throws IOException {
    if ( buf == null ) {
      throw new IOException("IO is closed");
    }
  }

  private long fillBuf(long length) throws IOException {
    if ( isOnDisk() || position + length > buf.capacity() ) {
      // Rotate the buffer to disk if it hasn't been done yet
      if ( !isOnDisk() ) {
        rotateToTmpFile();
      }

      return fillBufFromTmpFile(length);
    }
    else {
      return fillBufFromMem(length);
    }
  }

  private long fillBufFromMem(long length) throws IOException {
    long limit;
    int  len;

    limit = position + length;

    if ( buffered < limit ) {
      buf.limit((int) limit).position((int) buffered);

      len = io.read(buf);

      if ( len == -1 ) {
        if ( buffered <= position ) {
          return -1;
        }
      }
      else {
        buffered += len;

        if ( buffered <= position ) {
          return 0;
        }
      }
    }

    buf.limit((int) limit).position((int) position);
    return Math.min(buffered - position, length);
  }

  private long fillBufFromTmpFile(long length) throws IOException {
    long count = 0;
    int  len;

    // If we haven't buffered far enough, then do it
    if ( buffered < position ) {
      // Bail with an EOF if there isn't enough data to buffer
      // to the requested position.
      if ( !bufferTo(position) ) {
        return -1;
      }
    }

    buf.clear().limit((int) length);

    if ( buffered > position ) {
      tmpFile.position(position);
      len = tmpFile.read(buf);
      buf.flip();

      return len;
    }
    else {
      // Read from the network
      len = io.read(buf);

      if ( len == -1 ) {
        return -1;
      }

      buf.flip();

      tmpFile.position(buffered);
      tmpFile.write(buf);

      buffered += len;

      buf.position(0);

      return len;
    }
  }

  private boolean bufferTo(long pos) throws IOException {
    long limit;
    int  len;

    while ( buffered < pos ) {
      limit = Math.min(pos - buffered, buf.capacity());

      buf.clear().limit((int) limit);

      len = io.read(buf);

      if ( len == -1 ) {
        return false;
      }

      buf.flip();

      tmpFile.position(buffered);
      tmpFile.write(buf);

      buffered += len;
    }

    return true;
  }

  private boolean isInMemory() {
    return tmpFile == null;
  }

  private boolean isOnDisk() {
    return tmpFile != null;
  }

  private void rotateToTmpFile() throws IOException {
    File file;
    RandomAccessFile fileStream;

    file = File.createTempFile(TMPFILE_PREFIX, TMPFILE_SUFFIX);
    file.deleteOnExit();

    fileStream = new RandomAccessFile(file, "rw");
    tmpFile    = fileStream.getChannel();

    buf.clear().position(0).limit((int) buffered);
    tmpFile.write(buf);
    buf.clear();
  }
}
