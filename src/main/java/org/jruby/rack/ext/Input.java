/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.ext;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import org.jruby.rack.RackEnvironment;
import org.jruby.rack.servlet.RewindableInputStream;
import org.jruby.rack.util.ExceptionUtils;

/**
 * Native (Java) implementation of a Rack input.
 * Available in Ruby as the class <code>JRuby::Rack::Input</code>.
 *
 * @author nicksieger
 */
@SuppressWarnings("serial")
public class Input extends RubyObject {

    static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Input(runtime, klass);
        }
    };

    static RubyClass getClass(final Ruby runtime) {
        final RubyModule _JRuby_Rack = (RubyModule)
            runtime.getModule("JRuby").getConstantAt("Rack");
        return (RubyClass) _JRuby_Rack.getConstantAt("Input");
    }

    protected boolean rewindable;
    private InputStream input;
    protected int length = 0;

    public Input(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    private void initialize(final RackEnvironment env) {
        this.rewindable = env.getContext().getConfig().isRewindable();
        try {
            setInput( env.getInput() );
        }
        catch (IOException e) {
            throw ExceptionUtils.newIOError(getRuntime(), e);
        }
        this.length = env.getContentLength();
    }

    @JRubyMethod(required = 1)
    public IRubyObject initialize(final ThreadContext context, final IRubyObject input) {
        final Object arg = JavaEmbedUtils.rubyToJava(input);
        if ( arg instanceof InputStream ) {
            setInput( (InputStream) arg );
        }
        else if ( arg instanceof RackEnvironment ) {
            initialize((RackEnvironment) arg);
        }
        return context.nil;
    }

    /**
     * gets must be called without arguments and return a string, or nil on EOF.
     */
    @JRubyMethod()
    public IRubyObject gets(final ThreadContext context) {
        try {
            final int NEWLINE = 10;
            final byte[] bytes = readUntil(NEWLINE, 0);
            if ( bytes != null ) {
                return context.runtime.newString(new ByteList(bytes, false));
            }
            else {
                return context.nil;
            }
        }
        catch (IOException io) {
            throw context.runtime.newIOErrorFromException(io);
        }
    }

    /**
     * read behaves like IO#read. Its signature is read([length, [buffer]]). If given,
     * length must be an non-negative Integer (>= 0) or nil, and buffer must be a
     * String and may not be nil. If length is given and not nil, then this method
     * reads at most length bytes from the input stream. If length is not given or
     * nil, then this method reads all data until EOF. When EOF is reached, this
     * method returns nil if length is given and not nil, or "" if length is not
     * given or is nil. If buffer is given, then the read data will be placed into
     * buffer instead of a newly created String object.
     */
    @JRubyMethod(optional = 2)
    public IRubyObject read(final ThreadContext context, final IRubyObject[] args) {
        int readLen = 0;
        if ( args.length > 0 ) {
            long len = args[0].convertToInteger("to_i").getLongValue();
            readLen = (int) Math.min(len, Integer.MAX_VALUE);
        }
        final RubyString buffer = args.length > 1 ? args[1].convertToString() : null;
        try {
            final byte[] bytes = readUntil(MATCH_NONE, readLen);
            if ( bytes != null ) {
                if ( buffer != null ) {
                    buffer.clear();
                    buffer.cat(bytes);
                    return buffer;
                }
                return context.runtime.newString(new ByteList(bytes, false));
            }
            return readLen > 0 ? context.nil : RubyString.newEmptyString(context.runtime);
        }
        catch (IOException io) {
            throw context.runtime.newIOErrorFromException(io);
        }
    }

    /**
     * each must be called without arguments and only yield Strings.
     */
    @JRubyMethod
    public IRubyObject each(final ThreadContext context, final Block block) {
        final IRubyObject nil = context.runtime.getNil();
        IRubyObject line;
        while ( ( line = gets(context) ) != nil ) {
            block.yield(context, line);
        }
        return nil;
    }

    /**
     * rewind must be called without arguments. It rewinds the input stream back
     * to the beginning. It must not raise Errno::ESPIPE: that is, it may not be
     * a pipe or a socket. Therefore, handler developers must buffer the input
     * data into some rewindable object if the underlying input stream is not rewindable.
     */
    @JRubyMethod
    public IRubyObject rewind(final ThreadContext context) {
        if ( input != null ) {
            try { // inputStream.rewind if inputStream.respond_to?(:rewind)
                final Method rewind = getRewindMethod(input);
                if ( rewind != null ) rewind.invoke(input, (Object[]) null);
            }
            catch (IllegalArgumentException e) {
                throw context.runtime.newArgumentError(e.getMessage());
            }
            catch (InvocationTargetException e) {
                final Throwable target = e.getCause();
                if ( target instanceof IOException ) {
                    throw context.runtime.newIOErrorFromException((IOException) target);
                }
                throw context.runtime.newRuntimeError(target.getMessage());
            }
            catch (IllegalAccessException e) { /* NOOP */ }
        }
        return context.nil;
    }

    /**
     * Returns the size of the input.
     */
    @JRubyMethod
    public IRubyObject size(final ThreadContext context) {
        return context.runtime.newFixnum(length);
    }

    /**
     * Close the input. Exposed only to the Java side because the Rack spec says
     * that application code must not call close, so we don't expose a close method to Ruby.
     */
    public void close() {
        try {
            input.close();
        }
        catch (IOException e) { /* ignore */ }
    }

    protected void setInput(InputStream input) {
        if ( input != null && rewindable && getRewindMethod(input) == null ) {
            input = new RewindableInputStream(input);
        }
        this.input = input;
    }

    // NOTE: a bit useless now since we're only using RewindableInputStream
    // but it should work with a custom stream as well thus left as is ...
    private static Method getRewindMethod(InputStream input) {
        try {
            return input.getClass().getMethod("rewind", (Class<?>[]) null);
        }
        catch (NoSuchMethodException e) { /* NOOP */ }
        catch (SecurityException e) { /* NOOP */ }
        return null;
    }

    private static final int MATCH_NONE = Integer.MAX_VALUE;

    private byte[] readUntil(final int match, final int count) throws IOException {
        ByteArrayOutputStream bs = null;
        int b; long i = 0;
        do {
            b = input.read();
            if ( b == -1 ) break; // EOF

            if (bs == null) {
                bs = new ByteArrayOutputStream( count == 0 ? 128 : count );
            }
            bs.write(b);

            if ( ++i == count ) break; // read count bytes

        } while ( b != match );

        return bs == null ? null : bs.toByteArray();
    }

}
