/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.input;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyIO;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInput;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

import java.io.FilterInputStream;
import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public class RackNonRewindableInput extends RackBaseInput {
      private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new RackNonRewindableInput(runtime, klass);
        }
    };

    public static RubyClass getRackNonRewindableInputClass(Ruby runtime) {
        return RackBaseInput.getClass(runtime, "RackNonRewindableInput",
                RackBaseInput.getRackBaseInputClass(runtime), ALLOCATOR,
                RackNonRewindableInput.class);
    }

    public RackNonRewindableInput(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    public RackNonRewindableInput(Ruby runtime, RackEnvironment env) throws IOException {
        super(runtime, getRackNonRewindableInputClass(runtime), env);
    }

    @Override
    protected RackInput getDelegateInput() {
        if (delegateInput == null) {
            // override close so we don't actually close the servlet input stream
            FilterInputStream filterStream = new FilterInputStream(inputStream) {
                @Override
                public void close() {
                }
            };
            delegateInput = new RubyIORackInput(getRuntime(), new RubyIO(getRuntime(), filterStream));
        }
        return delegateInput;
    }
}
