/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.embed;

import java.io.IOException;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.javasupport.JavaUtil;

import org.jruby.rack.AbstractRackDispatcher;
import org.jruby.rack.DefaultRackApplication;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackResponseEnvironment;

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
        IRubyObject rubyContext = JavaUtil.convertJavaToRuby(runtime, context);
        IRubyObject rackModule = runtime.getModule("JRuby").getConstantAt("Rack");
        // `JRuby::Rack.context = context`
        rackModule.callMethod(runtime.getCurrentContext(), "context=", rubyContext);
        // TODO @deprecated only doing this due backwards compatibility :
        // user code should use JRuby::Rack.context instead of $servlet_context
        runtime.getGlobalVariables().set("$servlet_context", rubyContext);
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
        // TODO a fast draft (probably should use rack.errors) :
        context.log("Error:", re);
        response.sendError(500);
    }

    @Override
    protected void afterProcess(RackApplication app) throws IOException {
        // NOOP
    }
    
}
