/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.rack.servlet.RewindableInputStream;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * Specification for Rack input, translated to a Java interface.
 * @author nicksieger
 */
public class RackInput extends RubyObject {
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new RackInput(runtime, klass);
        }
    };

    public static RubyClass getClass(Ruby runtime, String name, RubyClass parent,
                                     ObjectAllocator allocator, Class annoClass) {
        RubyModule jrubyMod = runtime.getOrCreateModule("JRuby");
        RubyClass klass = jrubyMod.getClass(name);
        if (klass == null) {
            klass = jrubyMod.defineClassUnder(name, parent, allocator);
            klass.defineAnnotatedMethods(annoClass);
        }
        return klass;
    }

    public static RubyClass getRackInputClass(Ruby runtime) {
        return getClass(runtime, "RackInput", runtime.getObject(), ALLOCATOR, RackInput.class);
    }

    private InputStream inputStream;
    private int length;
    
    public RackInput(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    public RackInput(Ruby runtime, RackEnvironment env) throws IOException {
        super(runtime, getRackInputClass(runtime));
        this.inputStream = env.getInput();
        this.length = env.getContentLength();
    }

    @JRubyMethod(required = 1)
    public IRubyObject initialize(ThreadContext context, IRubyObject arg) {
        Object obj = JavaEmbedUtils.rubyToJava(arg);
        if (obj instanceof InputStream) {
            this.inputStream = (InputStream) obj;
        }
        this.length = 0;
        return getRuntime().getNil();
    }

    /**
     * gets must be called without arguments and return a string, or nil on EOF.
     */
    @JRubyMethod()
    public IRubyObject gets(ThreadContext context) {
        try {
            final int NEWLINE = 10;
            byte[] bytes = readUntil(NEWLINE, 0);
            if (bytes != null) {
                return getRuntime().newString(new ByteList(bytes));
            } else {
                return getRuntime().getNil();
            }
        } catch (IOException io) {
            throw getRuntime().newIOErrorFromException(io);
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
    public IRubyObject read(ThreadContext context, IRubyObject[] args) {
        int count = 0;
        if (args.length > 0) {
            long arg = args[0].convertToInteger("to_i").getLongValue();
            count = (int) Math.min(arg, Integer.MAX_VALUE);
        }
        RubyString string = null;
        if (args.length == 2) {
            string = args[1].convertToString();
        }

        try {
            byte[] bytes = readUntil(Integer.MAX_VALUE, count);
            if (bytes != null) {
                if (string != null) {
                    string.clear();
                    string.cat(bytes);
                    return string;
                }
                return getRuntime().newString(new ByteList(bytes));
            } else {
                if (count > 0) {
                    return getRuntime().getNil();
                } else {
                    return RubyString.newEmptyString(getRuntime());
                }
            }
        } catch (IOException io) {
            throw getRuntime().newIOErrorFromException(io);
        }
    }

    /**
     * each must be called without arguments and only yield Strings.
     */
    @JRubyMethod()
    public IRubyObject each(ThreadContext context, Block block) {
        IRubyObject nil = getRuntime().getNil();
        IRubyObject line = null;
        while ((line = gets(context)) != nil) {
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
    @JRubyMethod()
    public IRubyObject rewind(ThreadContext context) {
        if (inputStream instanceof RewindableInputStream) {
            try {
                ((RewindableInputStream) inputStream).rewind();
            } 
            catch (IOException e) { }
        }
        return getRuntime().getNil();
    }

    /**
     * Returns the size of the input.
     */
    @JRubyMethod()
    public IRubyObject size(ThreadContext context) {
        return getRuntime().newFixnum(length);
    }

    /**
     * Close the input. Exposed only to the Java side because the Rack spec says
     * that application code must not call close, so we don't expose a close method to Ruby.
     */
    public void close() {
        try {
            inputStream.close();
        } 
        catch (IOException e) { /* ignore */ }
    }

    private byte[] readUntil(int match, int count) throws IOException {
        ByteArrayOutputStream bs = null;
        int b;
        long i = 0;
        do {
            b = inputStream.read();
            
            if (b == -1) {
                break;
            }
            if (bs == null) {
                bs = new ByteArrayOutputStream( count == 0 ? 128 : count );
            }
            bs.write(b);
            if (count > 0 && ++i == count) {
                break;
            }
        } while (b != match);

        return bs == null ? null : bs.toByteArray();
    }
    
}
