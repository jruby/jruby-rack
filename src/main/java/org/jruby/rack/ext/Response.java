/*
 * The MIT License
 *
 * Copyright 2013 kares.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package org.jruby.rack.ext;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.channels.Channel;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;
import java.nio.channels.WritableByteChannel;
import java.util.Map;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyIO;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.rack.RackException;
import org.jruby.rack.RackResponse;
import org.jruby.rack.RackResponseEnvironment;
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.BlockBody;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.JavaInternalBlockBody;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * JRuby::Rack::Response - the bridge from a Rack response into a (Java)
 * (servlet) response environment, (re-)implemented mostly in Java ...
 *
 * @author kares
 */
@JRubyClass(name="JRuby::Rack::Response")
public class Response extends RubyObject implements RackResponse {

    protected static Boolean dechunk; // null means not set

    /**
     * Whether responses should de-chunk data (when chunked response detected).
     * @param context
     * @param self
     * @return a ruby boolean
     */
    @JRubyMethod(name = "dechunk?", meta = true)
    public static IRubyObject is_dechunk(final ThreadContext context, final IRubyObject self) {
        if ( dechunk == null ) return context.nil;
        return context.runtime.newBoolean(dechunk);
    }

    /**
     * @see #is_dechunk(ThreadContext, IRubyObject)
     */
    @JRubyMethod(name = "dechunk=", meta = true, required = 1)
    public static IRubyObject set_dechunk(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            dechunk = ((RubyBoolean) value).isTrue();
        }
        else {
            dechunk = ! value.isNil();
        }
        return value;
    }

    private static Integer channelChunkSize = 32 * 1024 * 1024; // 32 MB

    /**
     * Returns the channel chunk size to be used e.g. when a (send) file
     * response is detected. By setting this value to nil you force an "explicit"
     * byte buffer to be used when copying between channels.
     *
     * @note High values won't hurt when sending small files since most Java
     * (file) channel implementations handle this gracefully. However if you're
     * on Windows it is  recommended to not set this higher than the "magic"
     * number (64 * 1024 * 1024) - (32 * 1024) as there seems to be anecdotal
     * evidence that attempts to transfer more than 64MB at a time on certain
     * Windows versions results in a slow copy.
     * @see #get_channel_buffer_size(ThreadContext, IRubyObject)
     * @param context
     * @param self
     * @return a (ruby) integer value
     */
    @JRubyMethod(name = "channel_chunk_size", meta = true)
    public static IRubyObject get_channel_chunk_size(final ThreadContext context, final IRubyObject self) {
        if ( channelChunkSize == null ) return context.nil;
        return context.runtime.newFixnum(channelChunkSize);
    }

    /**
     * @see #get_channel_chunk_size(ThreadContext, IRubyObject)
     */
    @JRubyMethod(name = "channel_chunk_size=", meta = true, required = 1)
    public static IRubyObject set_channel_chunk_size(final IRubyObject self, final IRubyObject value) {
        if ( value.isNil() ) {
            channelChunkSize = null;
        }
        else {
            final long val = value.convertToInteger("to_i").getLongValue();
            channelChunkSize = Integer.valueOf((int) val);
        }
        return value;
    }

    protected static Integer channelBufferSize = 16 * 1024; // 16 kB

    /**
     * Returns a byte buffer size that will be allocated when copying between
     * channels. This usually won't happen at all (unless you return an exotic
     * channel backed object) as with file responses the response channel is
     * always transferable and thus {#channel_chunk_size} will be used.
     * @see #get_channel_chunk_size(ThreadContext, IRubyObject)
     * @param context
     * @param self
     * @return a (ruby) integer value
     */
    @JRubyMethod(name = "channel_buffer_size", meta = true)
    public static IRubyObject get_channel_buffer_size(final ThreadContext context, final IRubyObject self) {
        return context.runtime.newFixnum(channelBufferSize);
    }

    /**
     * @see #get_channel_buffer_size(ThreadContext, IRubyObject)
     */
    @JRubyMethod(name = "channel_buffer_size=", meta = true, required = 1)
    public static IRubyObject set_channel_buffer_size(final IRubyObject self, final IRubyObject value) {
        if ( value.isNil() ) {
            channelBufferSize = 16 * 1024;
        }
        else {
            final long val = value.convertToInteger("to_i").getLongValue();
            channelBufferSize = Integer.valueOf((int) val);
        }
        return value;
    }

    static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Response(runtime, klass);
        }
    };

    protected Response(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    private int status;
    private RubyHash headers;
    private IRubyObject body;

    /**
     * Expects a Rack response.
     * @param context
     * @param arg [status, headers, body]
     */
    @JRubyMethod(required = 1)
    public IRubyObject initialize(final ThreadContext context, final IRubyObject arg) {
        if ( arg instanceof RubyArray ) {
            final RubyArray arr = (RubyArray) arg;
            if ( arr.size() < 3 ) {
                throw context.runtime.newArgumentError("expected 3 array elements (rack-respose)");
            }
            this.status = (int) arr.eltInternal(0).convertToInteger("to_i").getLongValue();
            this.headers = arr.eltInternal(1).convertToHash();
            this.body = arr.eltInternal(2);
        }
        else {
            this.status = (int) arg.callMethod(context, "[]", context.runtime.newFixnum(0)).
                convertToInteger("to_i").getLongValue();
            this.headers = arg.callMethod(context, "[]", context.runtime.newFixnum(1)).convertToHash();
            this.body = arg.callMethod(context, "[]", context.runtime.newFixnum(2));
        }
        // HACK: deal with objects that don't comply with Rack specification
        if ( ! this.body.respondsTo("each_line") && ! this.body.respondsTo("each") ) {
            this.body = this.body.asString(); // previously @body = [ @body.to_s ]
        }
        return this;
    }

    @JRubyMethod
    public IRubyObject status(final ThreadContext context) {
        return context.runtime.newFixnum(status);
    }

    @JRubyMethod
    public IRubyObject body(final ThreadContext context) {
        return this.body;
    }

    @JRubyMethod
    public IRubyObject headers(final ThreadContext context) {
        return this.headers;
    }

    // RackResponse

    /**
     * @return the response status
     * @see RackResponse#getStatus()
     */
    public int getStatus() {
        return this.status;
    }

    /**
     * @return the headers hash
     * @see RackResponse#getHeaders()
     */
    @SuppressWarnings("unchecked")
    public Map<String, ?> getHeaders() {
        return this.headers;
    }

    /**
     * @return the response body (build up as a string)
     * @see RackResponse#getBody()
     */
    public String getBody() {
        if ( this.body instanceof RubyString ) return this.body.asJavaString();
        // body = ""; @body.each { |part| body << part }; body
        final ThreadContext context = getRuntime().getCurrentContext();
        try {
            final StringBuilder bodyParts = new StringBuilder();
            invoke(context, this.body, "each",
                new JavaInternalBlockBody(context.runtime, Arity.ONE_REQUIRED) {
                    @Override
                    public IRubyObject yield(ThreadContext context, IRubyObject part) {
                        bodyParts.append( part.asString().toString() );
                        return part;
                    }
                }
            );
            return bodyParts.toString();
        }
        finally {
            if ( this.body.respondsTo("close") ) {
                this.body.callMethod(context, "close");
            }
        }
    }

    /**
     * Respond this response with the given (servlet) response environment.
     * @see RackResponse#respond(RackResponseEnvironment)
     */
    public void respond(final RackResponseEnvironment response) throws RackException {
        if ( ! response.isCommitted() ) {
            try { // NOTE: we're assuming possible overrides are out of our NS
                if ( getMetaClass().getName().startsWith("JRuby::Rack") ) {
                    // do the Java 'optimized' version :
                    writeStatus(response);
                    writeHeaders(response);
                    writeBody(response);
                }
                else { // plain-old Ruby version
                    final ThreadContext context = currentContext();
                    final IRubyObject rubyResponse = JavaUtil.convertJavaToRuby(context.runtime, response);
                    callMethod(context, "write_status", rubyResponse);
                    callMethod(context, "write_headers", rubyResponse);
                    callMethod(context, "write_body", rubyResponse);
                }
            }
            catch (IOException e) { throw new RackException(e); }
        }
    }

    @JRubyMethod(name = "write_status")
    public IRubyObject write_status(final ThreadContext context, final IRubyObject response) {
        writeStatus( (RackResponseEnvironment) response.toJava(RackResponseEnvironment.class) );
        return context.nil;
    }

    protected void writeStatus(final RackResponseEnvironment response) {
        response.setStatus(this.status);
    }

    @JRubyMethod(name = "write_headers")
    public IRubyObject write_headers(final ThreadContext context, final IRubyObject response)
        throws IOException {
        writeHeaders( (RackResponseEnvironment) response.toJava(RackResponseEnvironment.class) );
        return context.nil;
    }

    private static final ByteList NEW_LINE = new ByteList(new byte[] { '\n' }, false);

    protected void writeHeaders(final RackResponseEnvironment response) throws IOException {
        this.headers.visitAll(new RubyHash.Visitor() { // headers.each { |key, val| }
            @Override
            public void visit(final IRubyObject key, final IRubyObject val) {
                final String name = key.toString();

                if ( name.equalsIgnoreCase("Content-Type") ) {
                    response.setContentType( val.asJavaString() ); return;
                }

                if ( name.equalsIgnoreCase("Content-Length") ) {
                    if ( isChunked() ) return;
                    final long length = val.convertToInteger("to_i").getLongValue();
                    if ( length < Integer.MAX_VALUE ) {
                        response.setContentLength( (int) length ); return;
                    } // else will do addHeader
                }

                if ( name.equals("Transfer-Encoding") ) {
                    if ( skipEncodingHeader(val) ) return;
                }

                // NOTE: effectively the same as `v.split("\n").each` which is what
                // rack handler does to guard against response splitting attacks !
                final boolean each_line = val.respondsTo("each_line");
                if ( each_line || val.respondsTo("each") ) {
                    final ThreadContext context = getRuntime().getCurrentContext();
                    final RubyString newLine = RubyString.newString(context.runtime, NEW_LINE);
                    // value.each_line { |val| response.addHeader(key.to_s, val.chomp("\n")) }
                    invoke(context, val, each_line ? "each_line" : "each",
                        new JavaInternalBlockBody(context.runtime, Arity.ONE_REQUIRED) {
                            @Override
                            public IRubyObject yield(ThreadContext context, IRubyObject value) {
                                value.callMethod(context, "chomp!", newLine);
                                response.addHeader(name, value.toString());
                                return value;
                            }
                        }
                    );
                    return;
                }

                if ( val instanceof RubyNumeric ) {
                    final long value = val.convertToInteger("to_i").getLongValue();
                    if ( value < Integer.MAX_VALUE ) {
                        response.addIntHeader(name, (int) value); return;
                    } // else will do addHeader
                }
                else if ( val instanceof RubyTime ) {
                    final long millis = ((RubyTime) val).getDateTime().getMillis();
                    response.addDateHeader(name, millis); return;
                }

                response.addHeader(name, val.toString());
            }
        });
    }

    @JRubyMethod(name = "write_body")
    public IRubyObject write_body(final ThreadContext context, final IRubyObject response)
        throws IOException {
        writeBody( (RackResponseEnvironment) response.toJava(RackResponseEnvironment.class) );
        return context.nil;
    }

    protected void writeBody(final RackResponseEnvironment response) throws IOException {
        Channel bodyChannel = null; IRubyObject body = this.body;
        try {
            if ( body.respondsTo("call") && ! body.respondsTo("each") ) {
                final ThreadContext context = currentContext();
                final IRubyObject outputStream =
                    JavaUtil.convertJavaToRuby(context.runtime, response.getOutputStream());
                this.body.callMethod(context, "call", outputStream);
                return;
            }

            if ( body.respondsTo("to_path") ) { // send_file
                final ThreadContext context = currentContext();
                final IRubyObject path = body.callMethod(context, "to_path");
                callMethod("send_file", path, JavaUtil.convertJavaToRuby(context.runtime, response));
                return;
            }

            if ( body.respondsTo("body_parts") ) {
                body = body.callMethod(currentContext(), "body_parts");
            }

            if ( body.respondsTo("to_channel") ) { // (body or body.body_parts).to_channel
                if ( body instanceof RubyIO ) {
                    bodyChannel = ((RubyIO) body).getChannel();
                }
                else {
                    final ThreadContext context = currentContext();
                    final IRubyObject channel = body.callMethod(context, "to_channel");
                    bodyChannel = (Channel) channel.toJava(Channel.class);
                }
                if ( bodyChannel instanceof FileChannel ) {
                    transferChannel( (FileChannel) bodyChannel, response.getOutputStream() );
                }
                else {
                    transferChannel( (ReadableByteChannel) bodyChannel, response.getOutputStream() );
                }
                return;
            }
            // NOTE: we no longer handle "to_inputstream" since in 1.7 "to_channel" covers those ...

            final OutputStream output = response.getOutputStream();
            final ThreadContext context = currentContext();
            if ( doDechunk() ) {
                final IRubyObject output_stream = JavaUtil.convertJavaToRuby(context.runtime, output);
                callMethod(context, "write_body_dechunked", output_stream);
            }
            else {
                final String method = body.respondsTo("each_line") ? "each_line" : "each";
                invoke(context, body, method,
                    new JavaInternalBlockBody(context.runtime, Arity.ONE_REQUIRED) {
                    @Override
                    public IRubyObject yield(ThreadContext context, IRubyObject line) {
                        //final ByteList bytes = line.asString().getByteList();
                        try {
                            output.write( line.asString().getBytes() );
                            //output.write(bytes.unsafeBytes(), bytes.getBegin(), bytes.getRealSize());
                            if ( doFlush() ) output.flush();
                        }
                        catch (IOException e) { throw new RackException(e); }
                        return context.nil;
                    }
                });
            }
        }
        catch (IOException e) { if ( ! isClientAbortException(e) ) throw e; }
        catch (RuntimeException e) { if ( ! isClientAbortException(e) ) throw e; }
        finally {
            if ( body.respondsTo("close") ) {
                body.callMethod(currentContext(), "close");
            }
            else if ( bodyChannel != null ) {
                bodyChannel.close(); // closing the channel closes the stream
            }
        }
    }

    /**
     * Sends a file when a Rails/Rack file response (`body.to_path`) is detected.
     * This allows for potential application server overrides when file streaming.
     * By default JRuby-Rack will stream the file using a (native) file channel.
     * @param context
     * @param path the file path
     * @param response the response environment
     * @throws IOException
     */
    @JRubyMethod(name = "send_file")
    public IRubyObject send_file(final ThreadContext context,
        final IRubyObject path, final IRubyObject response) throws IOException {
        // NOTE: That this is not related to `Rack::Sendfile` support, since if you
        // have configured *sendfile.type* (e.g. to Apache's "X-Sendfile") this part
        // would not have been executing at all.
        final RackResponseEnvironment servletResponse =
            (RackResponseEnvironment) response.toJava(Object.class);
        final FileInputStream input = new FileInputStream( path.asString().toString() );
        final FileChannel inputChannel = input.getChannel();
        try {
            transferChannel(inputChannel, servletResponse.getOutputStream());
        }
        finally {
            inputChannel.close();
            try { input.close(); } catch (IOException e) { /* ignored */ }
        }
        return context.nil;
    }

    @JRubyMethod(name = "chunked?")
    public IRubyObject chunked_p(final ThreadContext context) {
        return context.runtime.newBoolean( isChunked() );
    }

    private static final ByteList TRANSFER_ENCODING = new ByteList(
        new byte[] { 'T','r','a','n','s','f','e','r','-','E','n','c','o','d','i','n','g' },
    false);

    private Boolean chunked;

    /**
     * @return whether a chunked encoding is detected
     */
    public boolean isChunked() {
        if ( chunked != null ) return chunked;
        if ( this.headers != null ) {
            final RubyString key = RubyString.newString(getRuntime(), TRANSFER_ENCODING);
            final IRubyObject value = this.headers.callMethod("[]", key);
            if ( value instanceof RubyString ) {
                return chunked = ( (RubyString) value ).getByteList().equal(CHUNKED);
            }
        }
        return chunked = Boolean.FALSE;
    }

    /**
     * @return whether de-chunking (a chunked Rack response) should be performed
     */
    protected boolean doDechunk() {
        return dechunk == Boolean.TRUE && isChunked();
    }

    @JRubyMethod(name = "flush?")
    public IRubyObject flush_p(final ThreadContext context) {
        return context.runtime.newBoolean( doFlush() );
    }

    private static final ByteList CONTENT_LENGTH = new ByteList(
        new byte[] { 'C','o','n','t','e','n','t','-','L','e','n','g','t','h' },
    false);

    /**
     * @return whether output (body) should be flushed after each written line
     */
    protected boolean doFlush() {
        if ( isChunked() ) return true;
        if ( this.headers != null ) {
            final RubyString key = RubyString.newString(getRuntime(), CONTENT_LENGTH);
            final IRubyObject value = this.headers.callMethod("[]", key);
            return value.isNil(); // does not have a Content-Length header
        }
        return false;
    }

    protected boolean isClientAbortException(final Exception e) {
        String message = e.toString();
        while ( true ) {
            // e.g. org.apache.catalina.connector.ClientAbortException
            if ( message.contains("ClientAbortException") ) return true;
            if ( message.toLowerCase().contains("broken pipe") ) return true;
            if ( e.getCause() == null ) break;
            message = e.getCause().getMessage();
        }
        return false;
    }

    private static final ByteList CHUNKED = new ByteList(new byte[] { 'c','h','u','n','k','e','d' }, false);

    private boolean skipEncodingHeader(final IRubyObject value) {
        if ( dechunk == Boolean.FALSE ) return false;
        if ( value instanceof RubyString ) {
            return ( (RubyString) value ).getByteList().equal(CHUNKED);
        }
        return false;
    }

    public Integer getChannelChunkSize() {
        return channelChunkSize;
    }

    private void transferChannel(final FileChannel channel, final OutputStream output)
        throws IOException {
        final Integer chunkSize = getChannelChunkSize();
        if ( chunkSize != null && chunkSize > 0 ) {
            final WritableByteChannel outputChannel = Channels.newChannel(output);
            long pos = 0; final long size = channel.size();
            while ( pos < size ) {
                // for small sizes will (correctly) "ignore" the large chunk :
                pos += channel.transferTo(pos, chunkSize, outputChannel);
            }
        }
        else {
            transferChannel( (ReadableByteChannel) channel, output);
        }
    }

    public Integer getChannelBufferSize() {
        return channelBufferSize;
    }

    private void transferChannel(final ReadableByteChannel channel, final OutputStream output)
        throws IOException {
        final WritableByteChannel outputChannel = Channels.newChannel(output);

        final ByteBuffer buffer = ByteBuffer.allocate(getChannelBufferSize());

        while ( channel.read(buffer) != -1 ) {
            buffer.flip();
            outputChannel.write(buffer);
            buffer.compact();
        }
        buffer.flip();
        while ( buffer.hasRemaining() ) {
            outputChannel.write(buffer);
        }
    }

    ThreadContext currentContext() { return getRuntime().getCurrentContext(); }

    static IRubyObject invoke(
        final ThreadContext context, final IRubyObject self,
        final String method, final BlockBody body) {
        Block block = new Block(body, context.currentBinding(self, Visibility.PUBLIC));
        return Helpers.invoke(context, self, method, block);
    }

    @Override
    public Object toJava(Class target) {
        if ( target == null || target == RackResponse.class ) return this;
        return super.toJava(target);
    }

}
