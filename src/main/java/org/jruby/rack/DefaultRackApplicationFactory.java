/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import javax.servlet.ServletContext;
import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ClassCache;

/**
 *
 * @author nicksieger
 */
public class DefaultRackApplicationFactory implements RackApplicationFactory {
    private String rackupScript;
    private ServletContext servletContext;
    private ClassCache classCache;
    private RackApplication errorApplication;

    public void init(ServletContext servletContext) {
        this.servletContext = servletContext;
        this.rackupScript = servletContext.getInitParameter("rackup");
        this.classCache = JavaEmbedUtils.createClassCache(
                Thread.currentThread().getContextClassLoader());
        if (errorApplication == null) {
            errorApplication = newErrorApplication();
        }
    }

    public RackApplication newApplication() throws RackInitializationException {
        return createApplication(new ApplicationObjectFactory() {
            public IRubyObject create(Ruby runtime) {
                return createApplicationObject(runtime);
            }
        });
    }

    public RackApplication getApplication() throws RackInitializationException {
        RackApplication app = newApplication();
        app.init();
        return app;
    }

    public void finishedWithApplication(RackApplication app) {
        app.destroy();
    }

    public RackApplication getErrorApplication() {
        return errorApplication;
    }

    public void destroy() {
        errorApplication.destroy();
        errorApplication = null;
    }

    public Ruby newRuntime() throws RackInitializationException {
        try {
            RubyInstanceConfig config = new RubyInstanceConfig();
            config.setClassCache(classCache);
            try { // try to set jruby home to jar file path
                String binjruby = RubyInstanceConfig.class.getResource(
                        "/META-INF/jruby.home/bin/jruby").toURI().getPath();
                config.setJRubyHome(binjruby.substring(0, binjruby.length() - 10));
            } catch (Exception e) { }
            Ruby runtime = JavaEmbedUtils.initialize(new ArrayList(), config);
            runtime.getGlobalVariables().set("$servlet_context",
                    JavaEmbedUtils.javaToRuby(runtime, servletContext));
            runtime.evalScriptlet("require 'rack/handler/servlet'");
            return runtime;
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    public IRubyObject createApplicationObject(Ruby runtime) {
        return createRackServletWrapper(runtime, rackupScript);
    }

    public IRubyObject createErrorApplicationObject(Ruby runtime) {
        return createRackServletWrapper(runtime, "run JRuby::Rack::ErrorsApp.new");
    }

    public RackApplication newErrorApplication() {
        try {
            RackApplication app =
                    createApplication(new ApplicationObjectFactory() {
                public IRubyObject create(Ruby runtime) {
                    return createErrorApplicationObject(runtime);
                }
            });
            app.init();
            return app;
        } catch (final Exception e) {
            servletContext.log(
                "Warning: error application could not be initialized", e);
            return new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResponse call(ServletRequest env) {
                    return new RackResponse() {
                        public int getStatus() { return 500; }
                        public Map getHeaders() { return Collections.EMPTY_MAP; }
                        public String getBody() { return ""; }
                        public void respond(HttpServletResponse response) {
                            try {
                                response.sendError(500,
                                    "Application initialization failed: "
                                    + e.getMessage());
                            } catch (IOException ex) { }
                        }
                    };
                }
                public void destroy() { }
            };
        }
    }

    protected IRubyObject createRackServletWrapper(Ruby runtime, String rackup) {
        return runtime.evalScriptlet(
                "load 'jruby/rack/boot/rack.rb'\n"
                +"JRuby::Rack::Bootstrap.instance.change_to_root_directory\n"
                +"Rack::Handler::Servlet.new(Rack::Builder.new {( "
                + rackup + "\n )}.to_app)");
    }

    private interface ApplicationObjectFactory {
        IRubyObject create(Ruby runtime);
    }

    private RackApplication createApplication(final ApplicationObjectFactory appfact)
            throws RackInitializationException {
        try {
            final Ruby runtime = newRuntime();
            return new DefaultRackApplication() {
                @Override
                public void init() throws RackInitializationException {
                    try {
                        setApplication(appfact.create(runtime));
                    } catch (RaiseException re) {
                        throw new RackInitializationException(re);
                    }
                }
                @Override
                public void destroy() {
                    JavaEmbedUtils.terminate(runtime);
                }
            };
        } catch (RackInitializationException rie) {
            throw rie;
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    /** Used only for testing; not part of the public API. */
    public String verify(Ruby runtime, String script) {
        try {
            return runtime.evalScriptlet(script).toString();
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    /** Used only by unit tests */
    public void setErrorApplication(RackApplication app) {
        this.errorApplication = app;
    }
}
