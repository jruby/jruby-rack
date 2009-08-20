/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.input;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.RubyTempfile;
import org.jruby.anno.JRubyMethod;
import org.jruby.rack.RackEnvironment;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
import org.jruby.rack.RackInput;

/**
 * Suitable env['rack.input'] object for servlet environments, allowing to rewind the
 * input per the Rack specification.
 * @author nicksieger
 */
public class RackRewindableInput extends RackBaseInput {
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new RackRewindableInput(runtime, klass);
        }
    };

    public static RubyClass getRackRewindableInputClass(Ruby runtime) {
        return RackBaseInput.getClass(runtime, "RackRewindableInput",
                RackBaseInput.getRackBaseInputClass(runtime), ALLOCATOR,
                RackRewindableInput.class);
    }

    public static int getDefaultThreshold() {
        return DEFAULT_THRESHOLD;
    }

    public static void setDefaultThreshold(int thresh) {
        DEFAULT_THRESHOLD = thresh;
    }

    /** 64k is the default cutoff for buffering in memory. */
    private static int DEFAULT_THRESHOLD = 64 * 1024;

    private int threshold = DEFAULT_THRESHOLD;

    public RackRewindableInput(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    public RackRewindableInput(Ruby runtime, RackEnvironment env) throws IOException {
        super(runtime, getRackRewindableInputClass(runtime), env);
    }

    private class MemoryBufferRackInput implements RackInput {
        private ByteBuffer memoryBuffer;
        private boolean full;

        private MemoryBufferRackInput(ReadableByteChannel input) throws IOException {
            memoryBuffer = ByteBuffer.allocate(getBufferSize());
            while (input.read(memoryBuffer) > 0 && memoryBuffer.hasRemaining());
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

    private class RubyTempfileRackInput extends RubyIORackInput {
        private RubyTempfileRackInput(ReadableByteChannel input, ByteBuffer memoryBuffer) {
            super(getRuntime(), createTempfile(input, memoryBuffer));
        }

        public void close() {
            ((RubyTempfile) io).close_bang(getRuntime().getCurrentContext());
        }
    }

    /**
     * For testing, to allow the input threshold to be set from Ruby.
     */
    @JRubyMethod(name = "threshold=", visibility = Visibility.PRIVATE)
    public IRubyObject set_threshold(IRubyObject threshold) {
        this.threshold = (int) threshold.convertToInteger().getLongValue();
        return getRuntime().getNil();
    }

    protected RackInput getDelegateInput() {
        if (delegateInput == null) {
            try {
                ReadableByteChannel input = Channels.newChannel(inputStream);
                if (contentLength > threshold) {
                    delegateInput = new RubyTempfileRackInput(input, null);
                } else {
                    MemoryBufferRackInput memoryBufferInput = new MemoryBufferRackInput(input);
                    if (memoryBufferInput.isFull()) {
                        delegateInput = new RubyTempfileRackInput(input,
                                memoryBufferInput.getBuffer());
                    } else {
                        delegateInput = memoryBufferInput;
                    }
                }
            } catch (IOException io) {
                throw getRuntime().newIOErrorFromException(io);
            }
        }
        return delegateInput;
    }

    private RubyTempfile createTempfile(ReadableByteChannel input, ByteBuffer memoryBuffer) {
        getRuntime().getLoadService().require("tempfile");
        RubyTempfile tempfile = (RubyTempfile) RubyTempfile.open(getRuntime().getCurrentContext(),
                getRuntime().getClass("Tempfile"),
                new IRubyObject[]{getRuntime().newString("jruby-rack")},
                Block.NULL_BLOCK);
        try {
            FileChannel tempfileChannel = (FileChannel) tempfile.getChannel();
            long transferPosition = 0, bytesRead = 0;
            if (memoryBuffer != null) {
                transferPosition = tempfileChannel.write(memoryBuffer);
            }
            tempfileChannel.position(0);
            while ((bytesRead = tempfileChannel.transferFrom(input, transferPosition, 1024 * 1024)) > 0) {
                transferPosition += bytesRead;
            }
        } catch (IOException io) {
            throw getRuntime().newIOErrorFromException(io);
        }
        return tempfile;
    }

    /**
     * Favor content length over threshold to determine buffer size. In the case
     * of content length, set the buffer 1 larger so as to be able to detect
     * overflow/incorrect content length issues.
     *
     * NOTE: It's assumed that content length has already been verified to be
     * less than threshold.
     */
    private int getBufferSize() {
        int bufSize = threshold;
        if (contentLength > 0) {
            bufSize = contentLength + 1;
        }
        return bufSize;
    }
}
