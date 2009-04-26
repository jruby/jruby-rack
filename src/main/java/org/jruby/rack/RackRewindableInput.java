/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.ReadableByteChannel;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * Suitable env['rack.input'] object for servlet environments, allowing to rewind the
 * input per the Rack specification.
 * @author nicksieger
 */
public class RackRewindableInput extends RubyObject {
    public static RubyClass getClass(Ruby runtime) {
        RubyModule jrubyMod = runtime.getModule("JRuby");
        if (jrubyMod == null) {
            jrubyMod = runtime.getOrCreateModule("JRuby");
        }
        RubyClass klass = jrubyMod.getClass("RackRewindableInput");
        if (klass == null) {
            klass = jrubyMod.defineClassUnder("RackRewindableInput",
                    runtime.getObject(),
                    new ObjectAllocator() {
                        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
                            return new RackRewindableInput(runtime, klass);
                        }
                    });
            klass.defineAnnotatedMethods(RackRewindableInput.class);
        }
        return klass;
    }

    private InputStream inputStream;
    private ReadableByteChannel input;
    private ByteBuffer memoryBuffer;
    private static int THRESHOLD = 64 * 1024;

    public RackRewindableInput(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    public RackRewindableInput(Ruby runtime, InputStream input) {
        super(runtime, getClass(runtime));
        inputStream = input;
    }

    /**
     * gets must be called without arguments and return a string, or nil on EOF.
     */
    @JRubyMethod()
    public IRubyObject gets() {
        try {
            final int NEWLINE = 10; // 10 == '\n'
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
    public IRubyObject read(IRubyObject[] args) { // length, buffer
        long count = 0;
        if (args.length > 0) {
            count = args[0].convertToInteger("to_i").getLongValue();
        }
        RubyString string = null;
        if (args.length == 2) {
            string = args[1].convertToString();
        }

        try {
            byte[] bytes = readUntil(-1, count);
            if (bytes != null) {
                if (string != null) {
                    string.cat(bytes);
                    return string;
                }
                return getRuntime().newString(new ByteList(bytes));
            } else {
                return getRuntime().getNil();
            }
        } catch (IOException io) {
            throw getRuntime().newIOErrorFromException(io);
        }
    }

    /**
     * each must be called without arguments and only yield Strings.
     */
    @JRubyMethod()
    public IRubyObject each(Block block) {
        IRubyObject nil = getRuntime().getNil();
        IRubyObject line = null;
        while ((line = gets()) != nil) {
            block.yield(getRuntime().getCurrentContext(), line);
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
    public IRubyObject rewind() {
        if (memoryBuffer != null) {
            memoryBuffer.rewind();
        }
        return getRuntime().getNil();
    }

    /**
     * For testing, to allow the input stream to be set from Ruby.
     */
    @JRubyMethod(name = "stream=", visibility = Visibility.PRIVATE)
    public IRubyObject set_stream(IRubyObject stream) {
        Object obj = JavaEmbedUtils.rubyToJava(stream);
        if (obj instanceof InputStream) {
            inputStream = (InputStream) obj;
        }
        return getRuntime().getNil();
    }

    private byte readByte() throws IOException {
        initializeInput();
        if (memoryBuffer.hasRemaining()) {
            return memoryBuffer.get();
        } else {
            return -1;
        }
    }

    private byte[] readUntil(int end, long count) throws IOException {
        ByteArrayOutputStream bs = null;
        byte b;
        long i = 0;
        do {
            b = readByte();
            if (b == -1) {
                break;
            }
            if (bs == null) {
                bs = new ByteArrayOutputStream();
            }
            bs.write(b);
            if (count > 0 && ++i == count) {
                break;
            }
        } while (b != end);

        if (bs == null) {
            return null;
        }
        return bs.toByteArray();
    }

    private void initializeInput() throws IOException {
        if (input == null) {
            input = Channels.newChannel(inputStream);
            memoryBuffer = ByteBuffer.allocate(THRESHOLD);
            int numBytes = input.read(memoryBuffer);
            memoryBuffer.flip();
        }
    }
}
