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
import org.jruby.RubyObjectAdapter;
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
    private RubyObjectAdapter adapter = JavaEmbedUtils.newObjectAdapter();

    public RackResponse call(ServletRequest env) {
        Ruby runtime = getRuntime();
        try {
            final RubyIO io = new RubyIO(runtime, env.getInputStream());
            try {
                IRubyObject servlet_env = JavaEmbedUtils.javaToRuby(runtime, env);
                servlet_env.getMetaClass().defineMethod("to_io", new Callback() {
                        public IRubyObject execute(IRubyObject recv, IRubyObject[] args, Block block) {
                            return io;
                        }
                        public Arity getArity() { return Arity.NO_ARGUMENTS; }
                    });
                IRubyObject response = __call(servlet_env);
                return (RackResponse) JavaEmbedUtils.rubyToJava(runtime, response, RackResponse.class);
            } finally {
                try {
                    io.unregisterDescriptor(io.getOpenFile().getMainStream().getDescriptor().getFileno());
                } catch (Throwable t) {
                    // oh well, tried to ensure that the descriptor doesn't leak. keep going
                }
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

    public Ruby getRuntime() {
        return application.getRuntime();
    }

    /** Only used for testing. */
    public IRubyObject __call(final IRubyObject env) {
        return adapter.callMethod(application, "call", env);
    }
}
