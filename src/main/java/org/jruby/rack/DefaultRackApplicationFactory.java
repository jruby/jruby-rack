/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.util.ArrayList;
import javax.servlet.ServletContext;
import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.jruby.Ruby;
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
            Ruby runtime = JavaEmbedUtils.initialize(new ArrayList(), classCache);
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
        return createRackServletWrapper(runtime, "run JRuby::Rack::Errors");
    }

    public RackApplication newErrorApplication() {
        try {
            return createApplication(new ApplicationObjectFactory() {
                public IRubyObject create(Ruby runtime) {
                    return createErrorApplicationObject(runtime);
                }
            });
        } catch (final Exception e) {
            return new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResult call(ServletRequest env) {
                    return new RackResult() {
                        public void writeStatus(HttpServletResponse response) {
                            try {
                                response.sendError(500,
                                    "Application initialization failed: "
                                    + e.getMessage());
                            } catch (IOException ex) { }
                        }
                        public void writeHeaders(HttpServletResponse response) { }
                        public void writeBody(HttpServletResponse response) { }
                    };
                }
                public void destroy() { }
            };
        }
    }

    protected IRubyObject createRackServletWrapper(Ruby runtime, String rackup) {
        return runtime.evalScriptlet(
                "Rack::Handler::Servlet.new(Rack::Builder.new {( "
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
