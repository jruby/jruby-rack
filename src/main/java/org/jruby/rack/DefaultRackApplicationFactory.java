/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
    private RackContext rackContext;
    private ClassCache classCache;
    private RackApplication errorApplication;

    public void init(RackContext rackContext) {
        this.rackContext = rackContext;
        this.rackupScript = findRackupScript();
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
            setupJRubyManagement();
            Ruby runtime = JavaEmbedUtils.initialize(new ArrayList(), createRuntimeConfig());
            runtime.getGlobalVariables().set("$servlet_context",
                    JavaEmbedUtils.javaToRuby(runtime, rackContext));
            runtime.evalScriptlet("require 'rack/handler/servlet'");
            return runtime;
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    /**
     * JRuby 1.5 flips this setting to false by default for quicker
     * startup. Appserver startup time probably doesn't matter.
     */
    private void setupJRubyManagement() {
        if (!"false".equalsIgnoreCase(System.getProperty("jruby.management.enabled"))) {
            System.setProperty("jruby.management.enabled", "true");
        }
    }

    private RubyInstanceConfig createRuntimeConfig() {
        RubyInstanceConfig config = new RubyInstanceConfig();
        config.setClassCache(classCache);
        try { // try to set jruby home to jar file path
             String binfile = RubyInstanceConfig.class.getResource(
                    "/META-INF/jruby.home/bin/jirb").toURI().getSchemeSpecificPart();
             if (binfile.indexOf(".jar!") != -1 && binfile.indexOf("file:") != 0) {
                 binfile = "file:"+binfile;
             }
             config.setJRubyHome(binfile.substring(0, binfile.length() - "/bin/jirb".length()));
        } catch (Exception e) { }
        return config;
    }

    public IRubyObject createApplicationObject(Ruby runtime) {
        if (rackupScript == null) {
            rackContext.log("WARNING: no rackup script found. Starting empty Rack application.");
            rackupScript = "";
        }
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
            rackContext.log(
                "Warning: error application could not be initialized", e);
            return new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResponse call(RackEnvironment env) {
                    return new RackResponse() {
                        public int getStatus() { return 500; }
                        public Map getHeaders() { return Collections.EMPTY_MAP; }
                        public String getBody() {
                            return "Application initialization failed: "
                                    + e.getMessage();
                        }
                        public void respond(RackResponseEnvironment response) {
                            try {
                                response.defaultRespond(this);
                            } catch (IOException ex) {
                                rackContext.log("Error writing body", ex);
                            }
                        }
                    };
                }
                public void destroy() { }
                public Ruby getRuntime() { throw new UnsupportedOperationException("not supported"); }
            };
        }
    }

    protected IRubyObject createRackServletWrapper(Ruby runtime, String rackup) {
        return runtime.evalScriptlet(
                "load 'jruby/rack/boot/rack.rb'\n"
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

    private String findConfigRuPathInSubDirectories(String path, int level) {
        Set entries = rackContext.getResourcePaths(path);
        if (entries != null) {
            if (entries.contains(path + "config.ru")) {
                return path + "config.ru";
            }

            if (level > 0) {
                level--;
                for (Iterator i = entries.iterator(); i.hasNext(); ) {
                    String subpath = (String) i.next();
                    if (subpath.endsWith("/")) {
                        subpath = findConfigRuPathInSubDirectories(subpath, level);
                        if (subpath != null) {
                            return subpath;
                        }
                    }
                }
            }
        }
        return null;
    }

    private static final Pattern CODING = Pattern.compile("coding:\\s*(\\S+)");

    private String inputStreamToString(InputStream stream) {
        if (stream == null) {
            return null;
        }

        try {
            StringBuilder str = new StringBuilder();
            int c = stream.read();
            Reader reader;
            String coding = "UTF-8";
            if (c == '#') {     // look for a coding: pragma
                str.append((char) c);
                while ((c = stream.read()) != -1 && c != 10) {
                    str.append((char) c);
                }
                Matcher m = CODING.matcher(str.toString());
                if (m.find()) {
                    coding = m.group(1);
                }
            }

            str.append((char) c);
            reader = new InputStreamReader(stream, coding);

            while ((c = reader.read()) != -1) {
                str.append((char) c);
            }

            return str.toString();
        } catch (Exception e) {
            rackContext.log("Error reading rackup input", e);
            return null;
        }
    }

    private String findRackupScript() {
        String rackup = rackContext.getInitParameter("rackup");
        if (rackup != null) {
            return rackup;
        }

        rackup = rackContext.getInitParameter("rackup.path");

        if (rackup == null) {
            rackup = findConfigRuPathInSubDirectories("/WEB-INF/", 1);
        }

        if (rackup != null) {
            rackup = inputStreamToString(rackContext.getResourceAsStream(rackup));
        }

        return rackup;
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

    /** Used only by unit tests */
    public String getRackupScript() {
        return rackupScript;
    }
}
