/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.embed;

import java.io.IOException;

import org.jruby.Ruby;
import org.jruby.api.Access;
import org.jruby.javasupport.JavaUtil;
import org.jruby.rack.AbstractRackDispatcher;
import org.jruby.rack.DefaultRackApplication;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackResponseEnvironment;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * An embedded dispatcher.
 */
public class Dispatcher extends AbstractRackDispatcher {

    protected final IRubyObject application;
    private RackApplication rackApplication;

    public Dispatcher(RackContext rackContext, IRubyObject application) {
        super(rackContext);
        this.application = application;
        initialize();
    }

    private void initialize() {
        final Ruby runtime = application.getRuntime();
        // initialize embedded config (set stdout/stderr etc) :
        if (context instanceof Context) {
            ((Context) context).getConfig().doInitialize(runtime);
        }
        ThreadContext currentContext = runtime.getCurrentContext();
        // `JRuby::Rack.context = context`
        Access.getModule(currentContext, "JRuby")
                .getConstantAt(currentContext, "Rack")
                .callMethod(currentContext, "context=", JavaUtil.convertJavaToRuby(runtime, context));
    }

    @Override
    protected RackApplication getApplication() throws RackInitializationException {
        if (rackApplication == null) {
            rackApplication = new DefaultRackApplication(application);
            rackApplication.init();
        }
        return rackApplication;
    }

    @Override
    public void destroy() {
        if (rackApplication != null) rackApplication.destroy();
        rackApplication = null;
    }

    @Override
    protected void afterException(
            RackEnvironment env, Exception re,
            RackResponseEnvironment response) throws IOException {
        context.log("Error:", re);
        response.sendError(500);
    }

    @Override
    protected void afterProcess(RackApplication app) {
        // NOOP
    }

}
