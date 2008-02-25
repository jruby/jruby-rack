/*
 ***** BEGIN LICENSE BLOCK *****
 * Version: CPL 1.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Common Public
 * License Version 1.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/cpl-v10.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2007 Sun Microsystems, Inc.
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the CPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the CPL, the GPL or the LGPL.
 ***** END LICENSE BLOCK *****/

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

    public DefaultRackApplicationFactory() {
    }

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
            runtime.evalScriptlet("require 'rack/handler/servlet/bootstrap'");
            runtime.getGlobalVariables().set("$servlet_context",
                    JavaEmbedUtils.javaToRuby(runtime, servletContext));
            return runtime;
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    public IRubyObject createApplicationObject(Ruby runtime) {
        return createRackServletWrapper(runtime, rackupScript);
    }

    public IRubyObject createErrorApplicationObject(Ruby runtime) {
        runtime.evalScriptlet("require 'rack/handler/servlet/errors'");
        return createRackServletWrapper(runtime,
                "run Rack::Handler::Servlet::Errors");
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
