/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.io.IOException;

import org.jruby.Ruby;
import org.jruby.RubyObjectAdapter;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.rack.ext.Input;

/**
 * Default {@link RackApplication} implementation.
 * Takes a Servlet {@link RackEnvironment} and calls the Ruby application
 * (which is wrapped in a <code>Rack::Handler::Servlet</code> instance).
 * Returns the response converted to a Java {@link RackResponse} object.
 *
 * @see rack/handler/servlet.rb
 *
 * @author nicksieger
 */
public class DefaultRackApplication implements RackApplication {

    protected final RubyObjectAdapter adapter = JavaEmbedUtils.newObjectAdapter();

    protected IRubyObject application;

    /**
     * Implicit constructor, expects the {@link #setApplication(IRubyObject)} to
     * be called before this constructed application can be used.
     */
    public DefaultRackApplication() { /* NOOP */ }

    /**
     * @see #setApplication(IRubyObject)
     * @param application
     */
    public DefaultRackApplication(final IRubyObject application) {
        this();
        setApplication(application);
    }

    /**
     * @see RackApplication#call(RackEnvironment)
     */
    @Override
    public RackResponse call(final RackEnvironment env) {
        final Ruby runtime = getRuntime();
        try {
            final Input io = new Input(runtime, env);
            try {
                final IRubyObject servlet_env = JavaEmbedUtils.javaToRuby(runtime, env);
                if ( env instanceof RackEnvironment.ToIO ) {
                    ( (RackEnvironment.ToIO) env ).setIO(io);
                }
                else { // TODO this is @deprecated and will be removed ...
                    // NOTE JRuby 1.7.x does not like instance vars for Java :
                    // warning: instance vars on non-persistent Java type
                    // Java::OrgJrubyRackServlet::ServletRackEnvironment
                    // (http://wiki.jruby.org/Persistence)
                    runtime.evalScriptlet("require 'jruby/rack/environment'");
                    adapter.setInstanceVariable(servlet_env, "@_io", io);
                }
                final IRubyObject response = // app.call(env)
                    adapter.callMethod(getApplication(), "call", servlet_env);
                return (RackResponse) response.toJava(RackResponse.class);
            }
            finally {
                io.close();
            }
        }
        catch (IOException e) {
            throw RaiseException.createNativeRaiseException(runtime, e);
        }
    }

    @Override
    public void init() { /* NOOP */ }

    @Override
    public void destroy() { /* NOOP */ }

    /**
     * @return the application's Ruby runtime
     */
    @Override
    public Ruby getRuntime() {
        return getApplication().getRuntime();
    }

    /**
     * An application is expected to be set, if you need to test whether an
     * application is not null use the {@link #isApplicationSet()} method.
     * @return the application (Ruby) object
     * @throws IllegalStateException if not application is set
     */
    public IRubyObject getApplication() {
        if (application == null) {
            throw new IllegalStateException("no application set");
        }
        return application;
    }

    /**
     * Sets the application object.
     * @param application
     */
    public void setApplication(IRubyObject application) {
        this.application = application;
    }

    /**
     * @see #getApplication()
     * @return true if an application has been set
     */
    public boolean isApplicationSet() {
        return this.application != null;
    }

}
