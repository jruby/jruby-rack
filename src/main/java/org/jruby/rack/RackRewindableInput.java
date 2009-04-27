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
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubyTempfile;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
import org.jruby.util.SafePropertyAccessor;

/**
 * Suitable env['rack.input'] object for servlet environments, allowing to rewind the
 * input per the Rack specification.
 * @author nicksieger
 */
public class RackRewindableInput extends RubyObject implements RackInput {
    public static RubyClass getClass(Ruby runtime) {
        RubyModule jrubyMod = runtime.getOrCreateModule("JRuby");
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

    /** 64k is the default cutoff for buffering to disk. */
    public static final int DEFAULT_THRESHOLD = 64 * 1024;

    private InputStream inputStream;
    private int threshold = DEFAULT_THRESHOLD;
    private RackInput delegateInput;

    public RackRewindableInput(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    public RackRewindableInput(Ruby runtime, InputStream input) {
        super(runtime, getClass(runtime));
        inputStream = input;
        threshold = SafePropertyAccessor.getInt("jruby.rack.request.size.threshold.bytes", DEFAULT_THRESHOLD);
    }

    /**
     * gets must be called without arguments and return a string, or nil on EOF.
     */
    @JRubyMethod()
    public IRubyObject gets(ThreadContext context) {
        return getDelegateInput().gets(context);
    }

    @JRubyMethod(optional = 2)
    public IRubyObject read(ThreadContext context, IRubyObject[] args) {
        return getDelegateInput().read(context, args);
    }

    @JRubyMethod()
    public IRubyObject each(ThreadContext context, Block block) {
        return getDelegateInput().each(context, block);
    }

    @JRubyMethod()
    public IRubyObject rewind(ThreadContext context) {
        return getDelegateInput().rewind(context);
    }

    public void close() {
        getDelegateInput().close();
        delegateInput = null;
    }

    private class MemoryBufferRackInput implements RackInput {
        private ReadableByteChannel input;
        private ByteBuffer memoryBuffer;
        private boolean full;

        private MemoryBufferRackInput() throws IOException {
            input = Channels.newChannel(inputStream);
            memoryBuffer = ByteBuffer.allocate(threshold);
            input.read(memoryBuffer);          
            full = !memoryBuffer.hasRemaining();
            memoryBuffer.flip();
        }

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

        public IRubyObject read(ThreadContext context, IRubyObject[] args) {
            long count = 0;
            if (args.length > 0) {
                count = args[0].convertToInteger("to_i").getLongValue();
            }
            RubyString string = null;
            if (args.length == 2) {
                string = args[1].convertToString();
            }

            try {
                byte[] bytes = readUntil(Integer.MAX_VALUE, count);
                if (bytes != null) {
                    if (string != null) {
                        string.cat(bytes);
                        return string;
                    }
                    return getRuntime().newString(new ByteList(bytes));
                } else {
                    return RubyString.newEmptyString(getRuntime());
                }
            } catch (IOException io) {
                throw getRuntime().newIOErrorFromException(io);
            }
        }

        public IRubyObject each(ThreadContext context, Block block) {
            IRubyObject nil = getRuntime().getNil();
            IRubyObject line = null;
            while ((line = gets(context)) != nil) {
                block.yield(context, line);
            }
            return nil;
        }

        public IRubyObject rewind(ThreadContext context) {
            memoryBuffer.rewind();
            return getRuntime().getNil();
        }

        public void close() {
        }

        private boolean isFull() {
            return full;
        }

        private ReadableByteChannel getChannel() {
            return input;
        }

        private ByteBuffer getBuffer() {
            return memoryBuffer;
        }

        private byte[] readUntil(int match, long count) throws IOException {
            ByteArrayOutputStream bs = null;
            byte b;
            long i = 0;
            do {
                if (memoryBuffer.hasRemaining()) {
                    b = memoryBuffer.get();
                } else {
                    break;
                }
                if (bs == null) {
                    bs = new ByteArrayOutputStream();
                }
                bs.write(b);
                if (count > 0 && ++i == count) {
                    break;
                }
            } while (b != match);

            if (bs == null) {
                return null;
            }
            return bs.toByteArray();
        }
    }

    private class RubyTempfileRackInput implements RackInput {
        private RubyTempfile io;

        private RubyTempfileRackInput(ReadableByteChannel input, ByteBuffer memoryBuffer) {
            getRuntime().getLoadService().require("tempfile");
            io = (RubyTempfile) RubyTempfile.open(getRuntime().getCurrentContext(),
                    getRuntime().getClass("Tempfile"),
                    new IRubyObject[] { getRuntime().newString("jruby-rack") },
                    Block.NULL_BLOCK);
            try {
                FileChannel tempfileChannel = (FileChannel) io.getChannel();
                tempfileChannel.write(memoryBuffer);
                tempfileChannel.position(0);
                long position = threshold, bytesRead = 0;
                while ((bytesRead = tempfileChannel.transferFrom(input, position, 1024 * 1024)) > 0) {
                    position += bytesRead;
                }
            } catch (IOException io) {
                throw getRuntime().newIOErrorFromException(io);
            }
        }

        public IRubyObject gets(ThreadContext context) {
            return io.gets(context, NULL_ARRAY);
        }

        public IRubyObject read(ThreadContext context, IRubyObject[] args) {
            switch (args.length) {
                case 1:
                    return io.read(context, args[0]);
                case 2:
                    return io.read(context, args[0], args[1]);
                default:
                    return io.read(context);
            }
        }

        public IRubyObject each(ThreadContext context, Block block) {
            return io.each_line(context, NULL_ARRAY, block);
        }

        public IRubyObject rewind(ThreadContext context) {
            return io.rewind(context);
        }

        public void close() {
            io.close_bang(getRuntime().getCurrentContext());
        }
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

    /**
     * For testing, to allow the input threshold to be set from Ruby.
     */
    @JRubyMethod(name = "threshold=", visibility = Visibility.PRIVATE)
    public IRubyObject set_threshold(IRubyObject threshold) {
        this.threshold = (int) threshold.convertToInteger().getLongValue();
        return getRuntime().getNil();
    }

    private RackInput getDelegateInput() {
        if (delegateInput == null) {
            try {
                MemoryBufferRackInput memoryBufferInput = new MemoryBufferRackInput();
                if (memoryBufferInput.isFull()) {
                    delegateInput = 
                        new RubyTempfileRackInput(
                            memoryBufferInput.getChannel(),
                            memoryBufferInput.getBuffer());
                } else {
                    delegateInput = memoryBufferInput;
                }
            } catch (IOException io) {
                throw getRuntime().newIOErrorFromException(io);
            }
        }
        return delegateInput;
    }
}
