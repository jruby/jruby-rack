/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaUtil;
import org.jruby.rack.servlet.ServletRackContext;
import org.jruby.rack.servlet.RewindableInputStream;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.File;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 *
 * @author nicksieger
 */
public class DefaultRackApplicationFactory implements RackApplicationFactory {
    private String rackupScript, rackupLocation;
    private ServletRackContext rackContext;
    private RubyInstanceConfig runtimeConfig;
    private RackApplication errorApplication;

    public void init(RackContext rackContext) {
        this.rackContext = (ServletRackContext) rackContext;
        this.rackupScript = findRackupScript();
        this.runtimeConfig = createRuntimeConfig();
        rackContext.log(runtimeConfig.getVersionString());
        configureDefaults();
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
        if (app != null) app.destroy();
    }

    public synchronized RackApplication getErrorApplication() {
        if (errorApplication == null) {
            errorApplication = newErrorApplication();
        }
        return errorApplication;
    }

    public void destroy() {
        if (errorApplication != null) {
	        errorApplication.destroy();
	        errorApplication = null;
        }
    }

    public RackContext getRackContext() {
        return rackContext;
    }

    public IRubyObject createApplicationObject(Ruby runtime) {
        if (rackupScript == null) {
            rackContext.log("WARNING: no rackup script found. Starting empty Rack application.");
            rackupScript = "";
        }
        runtime.evalScriptlet("load 'jruby/rack/boot/rack.rb'");
        return createRackServletWrapper(runtime, rackupScript);
    }

    public IRubyObject createErrorApplicationObject(Ruby runtime) {
        runtime.evalScriptlet("load 'jruby/rack/boot/rack.rb'");
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
        return runtime.executeScript(
                "Rack::Handler::Servlet.new( " + 
                    "Rack::Builder.new { (" + rackup + "\n) }.to_app " + 
                ")",
                rackupLocation);
    }

    private interface ApplicationObjectFactory {
        IRubyObject create(Ruby runtime);
    }

    private RubyInstanceConfig createRuntimeConfig() {
        setupJRubyManagement();
        final RubyInstanceConfig config = new RubyInstanceConfig();
        config.setLoader(Thread.currentThread().getContextClassLoader());
        // Process arguments, namely any that might be in RUBYOPT
        config.processArguments(rackContext.getConfig().getRuntimeArguments());
        
        if (rackContext.getConfig().getCompatVersion() != null) {
            config.setCompatVersion(rackContext.getConfig().getCompatVersion());
        }

        // Don't affect the container and sibling web apps when ENV changes are made inside the Ruby app
        // There are quite a such things made in a typical Bundler based app.
        config.setUpdateNativeENVEnabled(false);

        try { // try to set jruby home to jar file path
            URL resource = RubyInstanceConfig.class.getResource("/META-INF/jruby.home");
            if (resource != null && resource.getProtocol().equals("jar")) {
                String home;
                try { // http://weblogs.java.net/blog/2007/04/25/how-convert-javaneturl-javaiofile
                    home = resource.toURI().getSchemeSpecificPart();
                } catch (URISyntaxException urise) {
                    home = resource.getPath();
                }

                // Trim trailing slash. It confuses OSGi containers...
                if (home.endsWith("/")) {
                    home = home.substring(0, home.length() - 1);
                }
                config.setJRubyHome(home);
            }
        } catch (Exception e) { }

        return config;
    }

    private void initializeRuntime(Ruby runtime) throws RackInitializationException {
        try {
            IRubyObject context = JavaUtil.convertJavaToRuby(runtime, rackContext);
            runtime.getGlobalVariables().set("$servlet_context", context);
            if (rackContext.getConfig().isIgnoreEnvironment()) {
                runtime.evalScriptlet("ENV.clear");
            }
            runtime.evalScriptlet("require 'rack/handler/servlet'");
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    /** This method is only public for unit tests */
    public Ruby newRuntime() throws RackInitializationException {
        Ruby runtime = Ruby.newInstance(runtimeConfig);
        initializeRuntime(runtime);
        return runtime;
    }

    private RackApplication createApplication(final ApplicationObjectFactory appFactory)
            throws RackInitializationException {
        try {
            final Ruby runtime = newRuntime();
            return new DefaultRackApplication() {
                @Override
                public void init() throws RackInitializationException {
                    try {
                        setApplication(appFactory.create(runtime));
                    } catch (RaiseException re) {
                        captureMessage(re);
                        throw new RackInitializationException(re);
                    }
                }
                @Override
                public void destroy() {
                    runtime.tearDown(false);
                }
            };
        } catch (RackInitializationException rie) {
            throw rie;
        } catch (RaiseException re) {
            throw new RackInitializationException(re);
        }
    }

    private void captureMessage(RaiseException rex) {
        try {
            IRubyObject rubyException = rex.getException();
            ThreadContext context = rubyException.getRuntime().getCurrentContext();
            rubyException.callMethod(context, "capture");
            rubyException.callMethod(context, "store");
        } catch (Exception e) {
            // won't be able to capture anything
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
        rackupLocation = "<web.xml>";

        String rackup = rackContext.getConfig().getRackup();
        if (rackup != null) return rackup;

        rackup = rackContext.getConfig().getRackupPath();

        if (rackup == null) {
            rackup = findConfigRuPathInSubDirectories("/WEB-INF/", 1);
        }
        if (rackup == null) { // google-appengine gem prefers it at /config.ru
            // appengine misses "/" resources. Search for it directly.
            String rackupPath = rackContext.getRealPath("/config.ru");
            if (rackupPath != null && new File(rackupPath).exists()) {
                rackup = "/config.ru";
            }
        }

        if (rackup != null) {
            rackupLocation = rackContext.getRealPath(rackup);
            rackup = inputStreamToString(rackContext.getResourceAsStream(rackup));
        }

        return rackup;
    }

    private void setupJRubyManagement() {
        if (!"false".equalsIgnoreCase(System.getProperty("jruby.management.enabled"))) {
            System.setProperty("jruby.management.enabled", "true");
        }
    }

    private void configureDefaults() {
        // configure (default) jruby.rack.request.size.[...] parameters :
        final RackConfig config = rackContext.getConfig();
        Integer iniSize = config.getInitialMemoryBufferSize();
        if (iniSize == null) iniSize = RewindableInputStream.INI_BUFFER_SIZE;
        Integer maxSize = config.getMaximumMemoryBufferSize();
        if (maxSize == null) maxSize = RewindableInputStream.MAX_BUFFER_SIZE;
        if (iniSize.intValue() > maxSize.intValue()) iniSize = maxSize;
        
        RewindableInputStream.setDefaultInitialBufferSize(iniSize);
        RewindableInputStream.setDefaultMaximumBufferSize(maxSize);
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
