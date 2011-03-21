/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.input;

import java.nio.channels.Channel;
import java.nio.channels.FileChannel;

import org.jruby.Ruby;
import org.jruby.RubyIO;
import org.jruby.rack.RackInput;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

public class RubyIORackInput implements RackInput {
    protected final RubyIO io;

    public RubyIORackInput(Ruby runtime, RubyIO io) {
        this.io = io;
        this.io.binmode();
    }

    public IRubyObject gets(ThreadContext context) {
        return io.gets(context);
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
        return io.each_line(context, IRubyObject.NULL_ARRAY, block);
    }

    public IRubyObject rewind(ThreadContext context) {
        return io.rewind(context);
    }

    public IRubyObject size(ThreadContext context) {
        Channel channel = io.getChannel();
        try {
            if (channel instanceof FileChannel) {
                return context.getRuntime().newFixnum(((FileChannel) channel).size());
            }
        } catch (Exception e) {
            if (context.getRuntime().isDebug()) {
                e.printStackTrace();
            }
        }
        throw context.getRuntime().newNotImplementedError("not supported");
    }

    public void close() {
    }
}
