/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import org.jruby.Ruby;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.RubyObjectAdapter;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.SafePropertyAccessor;

import org.jruby.rack.input.RackBaseInput;
import org.jruby.rack.input.RackNonRewindableInput;
import org.jruby.rack.input.RackRewindableInput;

/**
 *
 * @author nicksieger
 */
public class DefaultRackApplication implements RackApplication {
    private final boolean rewindable;
    private final RubyObjectAdapter adapter = JavaEmbedUtils.newObjectAdapter();
    private IRubyObject application;

    public DefaultRackApplication() {
        rewindable = SafePropertyAccessor.getBoolean("jruby.rack.input.rewindable", true);
    }

    public RackResponse call(final RackEnvironment env) {
        Ruby runtime = getRuntime();
        try {
            RackBaseInput io = createRackInput(runtime, env);
            try {
                IRubyObject servlet_env = JavaEmbedUtils.javaToRuby(runtime, env);
                adapter.setInstanceVariable(servlet_env, "@_io", io);
                IRubyObject response = __call(servlet_env);
                return (RackResponse) JavaEmbedUtils.rubyToJava(runtime, response, RackResponse.class);
            } finally {
                io.close();
            }
        } catch (IOException ex) {
            throw RaiseException.createNativeRaiseException(runtime, ex);
        }
    }

    public void init() throws RackInitializationException {
    }

    public void destroy() {
    }

    public Ruby getRuntime() {
        return application.getRuntime();
    }

    public void setApplication(IRubyObject application) {
        this.application = application;
    }

    /** Only used for testing. */
    public IRubyObject __call(final IRubyObject env) {
        return adapter.callMethod(application, "call", env);
    }

    private RackBaseInput createRackInput(Ruby runtime, RackEnvironment env) throws IOException {
        if (rewindable) {
            return new RackRewindableInput(runtime, env);
        } else {
            return new RackNonRewindableInput(runtime, env);
        }
    }
}
