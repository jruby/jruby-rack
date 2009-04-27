/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.input.RackRewindableInput;
import java.io.IOException;
import org.jruby.Ruby;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.RubyObjectAdapter;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class DefaultRackApplication implements RackApplication {
    private IRubyObject application;
    private RubyObjectAdapter adapter = JavaEmbedUtils.newObjectAdapter();

    public RackResponse call(final RackEnvironment env) {
        Ruby runtime = getRuntime();
        try {
            RackRewindableInput io = new RackRewindableInput(runtime, env.getInput());
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
}
