/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.input;

import java.io.InputStream;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyIO;
import org.jruby.rack.RackInput;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

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

    public RackNonRewindableInput(Ruby runtime, InputStream stream) {
        super(runtime, getRackNonRewindableInputClass(runtime), stream);
    }

    @Override
    protected RackInput getDelegateInput() {
        if (delegateInput == null) {
            delegateInput = new RubyIORackInput(getRuntime(), 
                    new RubyIO(getRuntime(), inputStream)) {
                public void close() {
                    // we don't want to actually close the servlet input stream
                    // just try to ensure the descriptor doesn't leak
                    try {
                        io.unregisterDescriptor(io.getOpenFile().getMainStream().getDescriptor().getFileno());
                    } catch (Throwable t) {
                        // oh well
                    }
                }
            };
        }
        return delegateInput;
    }
}
