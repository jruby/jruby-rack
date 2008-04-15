/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.ServletRequest;
import org.jruby.Ruby;
import org.jruby.RubyIO;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.callback.Callback;

/**
 *
 * @author nicksieger
 */
public class DefaultRackApplication implements RackApplication {
    private IRubyObject application;

    public RackResponse call(final ServletRequest env) {
        Ruby runtime = application.getRuntime();
        IRubyObject servlet_env = JavaEmbedUtils.javaToRuby(runtime, env);
        servlet_env.getMetaClass().defineMethod("to_io", new Callback() {
            public IRubyObject execute(IRubyObject recv, IRubyObject[] args, Block block) {
                try {
                    return new RubyIO(recv.getRuntime(), env.getInputStream());
                } catch (IOException ex) {
                    throw RaiseException.createNativeRaiseException(recv.getRuntime(), ex);
                }
            }
            public Arity getArity() {
                return Arity.NO_ARGUMENTS;
            }
        });
        IRubyObject response = application.callMethod(runtime.getCurrentContext(),
                "call", new IRubyObject[] { servlet_env });
        return (RackResponse) JavaEmbedUtils.rubyToJava(runtime, response, RackResponse.class);
    }

    public void init() throws RackInitializationException {
    }

    public void destroy() {
    }

    public void setApplication(IRubyObject application) {
        this.application = application;
    }
}
