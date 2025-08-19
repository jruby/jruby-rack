/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;


import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Map;
import java.util.Set;

import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaUtil;
import org.jruby.rack.servlet.RewindableInputStream;
import org.jruby.rack.servlet.ServletRackContext;
import org.jruby.rack.util.IOHelpers;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.cli.OutputStrings;

import static org.jruby.rack.DefaultRackConfig.isIgnoreRUBYOPT;
import static org.jruby.rack.RackLogger.Level.*;

/**
 * Default application factory creates a new application instance on each
 * {@link #getApplication()} invocation. It does not manage applications it
 * creates (except for the error application that is assumed to be shared).
 *
 * @see SharedRackApplicationFactory
 * @see PoolingRackApplicationFactory
 *
 * @author nicksieger
 */
public class DefaultRackApplicationFactory implements RackApplicationFactory {

    private String rackupScript, rackupLocation;
    private ServletRackContext rackContext;
    private RubyInstanceConfig runtimeConfig;
    private RackApplication errorApplication;

    /**
     * Convenience helper for unwrapping a {@link RackApplicationFactoryDecorator}.
     * @param factory the (likely decorated) factory
     * @return unwrapped "real" factory (might be the same as given)
     */
    public static RackApplicationFactory getRealFactory(final RackApplicationFactory factory) {
        if ( factory instanceof RackApplicationFactory.Decorator ) {
            return getRealFactory( ((Decorator) factory).getDelegate() );
        }
        return factory;
    }

    public RackContext getRackContext() {
        return rackContext;
    }

    public String getRackupScript() {
        return rackupScript;
    }

    public void setRackupScript(String rackupScript) {
        this.rackupScript = rackupScript;
        this.rackupLocation = null;
    }

    /**
     * Initialize this factory using the given context.
     *
     * @implNote exception handling is left to the outer factory.
     * @param rackContext the RackContext
     */
    @Override
    public void init(final RackContext rackContext) {
        // NOTE: this factory is not supposed to be directly exposed
        // thus does not wrap exceptions into RackExceptions here ...
        // same applies for #newApplication() and #getApplication()
        this.rackContext = (ServletRackContext) rackContext;
        if ( getRackupScript() == null ) resolveRackupScript();
        this.runtimeConfig = createRuntimeConfig();
        rackContext.log(INFO, OutputStrings.getVersionString());
        configureDefaults();
    }

    /**
     * Creates a new application instance (without initializing it).
     *
     * @implNote exception handling is left to the outer factory.
     * @return new application instance
     */
    @Override
    public RackApplication newApplication() {
        return createApplication(this::createApplicationObject);
    }

    /**
     * Creates a new application and initializes it.
     *
     * @implNote exception handling is left to the outer factory.
     * @return new, initialized application
     */
    @Override
    public RackApplication getApplication() {
        final RackApplication app = newApplication();
        app.init();
        return app;
    }

    /**
     * Destroys the application (assumably) created by this factory.
     *
     * @implNote exception handling is left to the outer factory.
     * @param app the application to "release"
     */
    @Override
    public void finishedWithApplication(final RackApplication app) {
        if ( app != null ) app.destroy();
    }

    /**
     * @return the (default) error application
     */
    @Override
    public RackApplication getErrorApplication() {
        if (errorApplication == null) {
            synchronized(this) {
                if (errorApplication == null) {
                    errorApplication = newErrorApplication();
                }
            }
        }
        return errorApplication;
    }

    /**
     * Set the (default) error application to be used.
     * @param errorApplication the error application
     */
    public synchronized void setErrorApplication(RackApplication errorApplication) {
        this.errorApplication = errorApplication;
    }

    @Override
    public void destroy() {
        if (errorApplication != null) {
            synchronized(this) {
                if (errorApplication != null) {
                    errorApplication.destroy();
                    errorApplication = null;
                }
            }
        }
    }

    public IRubyObject createApplicationObject(final Ruby runtime) {
        if (rackupScript == null) {
            rackContext.log(WARN, "no rackup script found - starting empty Rack application!");
            rackupScript = "";
        }
        checkAndSetRackVersion(runtime);
        runtime.evalScriptlet("load 'jruby/rack/boot/rack.rb'");
        return createRackServletWrapper(runtime, rackupScript, rackupLocation);
    }

    public IRubyObject createErrorApplicationObject(final Ruby runtime) {
        String errorApp = rackContext.getConfig().getProperty("jruby.rack.error.app");
        String errorAppPath = "<web.xml>";
        if (errorApp == null) {
            errorApp = rackContext.getConfig().getProperty("jruby.rack.error.app.path");
            if (errorApp != null) {
                errorAppPath = rackContext.getRealPath(errorApp);
                try {
                    errorApp = IOHelpers.inputStreamToString(rackContext.getResourceAsStream(errorApp));
                }
                catch (IOException e) {
                    rackContext.log(WARN,
                        "failed to read jruby.rack.error.app.path = '" + errorApp + "' " +
                        "will use default error application", e);
                    errorApp = errorAppPath = null;
                }
            }

        }
        if (errorApp == null) {
            errorApp = "require 'jruby/rack/error_app' \n" +
            "use JRuby::Rack::ErrorApp::ShowStatus \n" +
            "run JRuby::Rack::ErrorApp.new";
        }
        runtime.evalScriptlet("load 'jruby/rack/boot/rack.rb'");
        return createRackServletWrapper(runtime, errorApp, errorAppPath);
    }

    public RackApplication newErrorApplication() {
        Boolean error = rackContext.getConfig().getBooleanProperty("jruby.rack.error");
        if ( error != null && ! error.booleanValue() ) { // jruby.rack.error = false
            return new DefaultErrorApplication(rackContext);
        }
        try {
            RackApplication app = createErrorApplication(
                    this::createErrorApplicationObject
            );
            app.init();
            return app;
        }
        catch (Exception e) {
            rackContext.log(WARN, "error application could not be initialized", e);
            return new DefaultErrorApplication(rackContext); // backwards compatibility
        }
    }

    /**
     * @see #createRackServletWrapper(Ruby, String, String)
     * @param runtime the JRuby runtime
     * @param rackup the rackup string
     * @return (Ruby) built Rack Servlet handler
     */
    protected IRubyObject createRackServletWrapper(Ruby runtime, String rackup) {
        return createRackServletWrapper(runtime, rackup, null);
    }

    /**
     * Creates the handler to bridge the Servlet and Rack worlds.
     * @param runtime the JRuby runtime
     * @param rackup the rackup string
     * @param filename the filename
     * @return (Ruby) built Rack Servlet handler
     */
    protected IRubyObject createRackServletWrapper(Ruby runtime, String rackup, String filename) {
        return runtime.executeScript(
            "Rack::Handler::Servlet.new( " +
                "Rack::Builder.new { (" + rackup + "\n) }.to_app " +
            ")", filename
        );
    }

    static interface ApplicationObjectFactory {
        IRubyObject create(Ruby runtime) ;
    }

    public RubyInstanceConfig createRuntimeConfig() {
        setupJRubyManagement();
        return initRuntimeConfig(new RubyInstanceConfig());
    }

    protected RubyInstanceConfig initRuntimeConfig(final RubyInstanceConfig config) {
        final RackConfig rackConfig = rackContext.getConfig();

        config.setLoader(Thread.currentThread().getContextClassLoader());

        // Don't affect the container and sibling web apps when ENV changes are
        // made inside the Ruby app ...
        // There are quite a such things made in a typical Bundler based app.
        try { // config.setUpdateNativeENVEnabled(false) using reflection :
            final Method setUpdateNativeENVEnabled =
                config.getClass().getMethod("setUpdateNativeENVEnabled", Boolean.TYPE);
            setUpdateNativeENVEnabled.invoke(config, false);
        }
        catch (NoSuchMethodException e) { // ignore method has been added in JRuby 1.6.7
            rackContext.log(DEBUG, "envronment changes made inside one app " +
            "might affect another, consider updating JRuby if this is an issue");
        }
        catch (IllegalAccessException e) {
            rackContext.log(WARN, "failed to disable updating native environment", e);
        }
        catch (InvocationTargetException e) {
            throw new RackException(e.getTargetException());
        }

        final Map<String, String> newEnv = rackConfig.getRuntimeEnvironment();
        if ( newEnv != null ) {
            if ( ! newEnv.containsKey("PATH") ) {
                // bundler 1.1.x assumes ENV['PATH'] is a string
                // `ENV['PATH'].split(File::PATH_SEPARATOR)` ...
                newEnv.put("PATH", ""); // ENV['PATH'] = ''
            }
            // bundle exec sets RUBYOPT="-I[...]/gems/bundler/lib -rbundler/setup"
            if ( isIgnoreRUBYOPT(rackConfig) ) {
                if ( newEnv.containsKey("RUBYOPT") ) newEnv.put("RUBYOPT", "");
            }
            else {
                // allow to work (backwards) "compatibly" with previous `ENV.clear`
                // RUBYOPT was processed since it happens on config.processArguments
                @SuppressWarnings("unchecked")
                final Map<String, String> env = config.getEnvironment();
                if ( env != null && env.containsKey("RUBYOPT") ) {
                    newEnv.put( "RUBYOPT", env.get("RUBYOPT") );
                }
            }
            config.setEnvironment(newEnv);
        }

        // Process arguments, namely any that might be in RUBYOPT
        config.processArguments(rackConfig.getRuntimeArguments());

        if ( rackConfig.getCompatVersion() != null ) {
            config.setCompatVersion(rackConfig.getCompatVersion());
        }

        try { // try to set jruby home to jar file path
            final URL resource = Ruby.class.getResource("/META-INF/jruby.home");
            if ( resource != null && "jar".equals( resource.getProtocol() ) ) {
                String home = config.getJRubyHome(); // uri: protocol only since 9k :
                if ( home == null || ! home.startsWith("uri:classloader:") ) {
                    try {
                        home = resource.toURI().getSchemeSpecificPart();
                    }
                    catch (URISyntaxException e) {
                        home = resource.getPath();
                    }

                    final int last = home.length() - 1; // trailing '/' confuses OSGi containers...
                    if ( home.charAt(last) == '/' ) home = home.substring(0, last);

                    config.setJRubyHome(home);
                }
            }
        }
        catch (Exception e) {
            rackContext.log(DEBUG, "won't set-up jruby.home from jar", e);
        }

        return config;
    }

    public Ruby newRuntime() throws RaiseException {
        final Ruby runtime = Ruby.newInstance(runtimeConfig);
        initRuntime(runtime);
        return runtime;
    }

    protected void loadJRubyRack(final Ruby runtime) {
        org.jruby.rack.ext.RackLibrary.load(runtime);
    }

    /**
     * Initializes the runtime (exports the context, boots the Rack handler).
     *
     * @apiNote Internal API, only visible due tests.
     *
     * @param runtime the JRuby runtime
     */
    public void initRuntime(final Ruby runtime) {
        loadJRubyRack(runtime);
        // set $servlet_context :
        runtime.getGlobalVariables().set(
            "$servlet_context", JavaUtil.convertJavaToRuby(runtime, rackContext)
        );
        // load our (servlet) Rack handler :
        runtime.evalScriptlet("require 'rack/handler/servlet'");

        // NOTE: this is experimental stuff and might change in the future :
        String env = rackContext.getConfig().getProperty("jruby.rack.handler.env");
        // currently supported "env" values are 'default' and 'servlet'
        if ( env != null ) {
            runtime.evalScriptlet("Rack::Handler::Servlet.env = '" + env + "'");
        }
        String response = rackContext.getConfig().getProperty("jruby.rack.handler.response");
        if ( response == null ) {
            response = rackContext.getConfig().getProperty("jruby.rack.response");
        }
        if ( response != null ) { // JRuby::Rack::JettyResponse -> 'jruby/rack/jetty_response'
            runtime.evalScriptlet("Rack::Handler::Servlet.response = '" + response + "'");
        }

        // configure (Ruby) bits and pieces :
        String dechunk = rackContext.getConfig().getProperty("jruby.rack.response.dechunk");
        Boolean dechunkFlag = (Boolean) DefaultRackConfig.toStrictBoolean(dechunk, null);
        if ( dechunkFlag != null ) {
            runtime.evalScriptlet("JRuby::Rack::Response.dechunk = " + dechunkFlag + "");
        }
        else { // dechunk null (default) or not a true/false value ... we're patch :
            runtime.evalScriptlet("JRuby::Rack::Booter.on_boot { require 'jruby/rack/chunked' }");
            // `require 'jruby/rack/chunked'` that happens after Rack is loaded
        }
        String swallowAbort = rackContext.getConfig().getProperty("jruby.rack.response.swallow_client_abort");
        Boolean swallowAbortFlag = (Boolean) DefaultRackConfig.toStrictBoolean(swallowAbort, null);
        if ( swallowAbortFlag != null ) {
            runtime.evalScriptlet("JRuby::Rack::Response.swallow_client_abort = " + swallowAbortFlag + "");
        }
    }

    /**
     * Checks and sets the required Rack version (if specified as a magic comment).
     *
     * e.g. # rack.version: =1.3.6
     *
     * @apiNote Internal API, only visible due tests.
     *
     * @param runtime the JRuby runtime
     * @return the rack version requirement
     */
    public String checkAndSetRackVersion(final Ruby runtime) {
        String rackVersion = null;
        try {
            rackVersion = IOHelpers.rubyMagicCommentValue(rackupScript, "rack.version:");
        }
        catch (Exception e) {
            rackContext.log(DEBUG, "could not read 'rack.version' magic comment from rackup", e);
        }

        if ( rackVersion == null ) {
            // NOTE: try matching a `require 'bundler/setup'` line ... maybe not ?!
        }
        if ( rackVersion != null ) {
            runtime.evalScriptlet("require 'rubygems'");

            if ( rackVersion.equalsIgnoreCase("bundler") ) {
                runtime.evalScriptlet("require 'bundler/setup'");
            }
            else {
                rackContext.log(DEBUG, "detected 'rack.version' magic comment, " +
                        "will use `gem 'rack', '"+ rackVersion +"'`");
                runtime.evalScriptlet("gem 'rack', '"+ rackVersion +"' if defined? gem");
            }
        }
        return rackVersion;
    }

    private RackApplication createApplication(final ApplicationObjectFactory appFactory) {
        return new RackApplicationImpl(appFactory);
    }

    /**
     * The application implementation this factory is producing.
     */
    private class RackApplicationImpl extends DefaultRackApplication {

        protected final Ruby runtime;
        final ApplicationObjectFactory appFactory;

        RackApplicationImpl(ApplicationObjectFactory appFactory) {
            this.runtime = newRuntime();
            this.appFactory = appFactory;
        }

        @Override
        public void init() {
            try {
                setApplication(appFactory.create(runtime));
            }
            catch (RaiseException e) {
                captureMessage(e);
                throw e;
            }
        }

        @Override
        public void destroy() {
            runtime.tearDown(false);
        }

    }

    private RackApplication createErrorApplication(final ApplicationObjectFactory appFactory) {
        // final Ruby runtime = newRuntime();
        return new ErrorApplicationImpl(appFactory);
    }

    private class ErrorApplicationImpl extends RackApplicationImpl implements ErrorApplication {

        ErrorApplicationImpl(ApplicationObjectFactory appFactory) {
            super(appFactory);
        }

        @Override
        public void init() {
            setApplication(appFactory.create(runtime));
        }

    }

    private void captureMessage(final RaiseException re) {
        try {
            IRubyObject rubyException = re.getException();
            ThreadContext context = rubyException.getRuntime().getCurrentContext();
            // JRuby-Rack internals (@see jruby/rack/capture.rb) :
            rubyException.callMethod(context, "capture");
            rubyException.callMethod(context, "store");
        }
        catch (Exception e) {
            rackContext.log(INFO, "failed to capture exception message", e);
            // won't be able to capture anything
        }
    }

    private String findConfigRuPathInSubDirectories(final String path, int level) {
        @SuppressWarnings("unchecked")
        final Set<String> entries = rackContext.getResourcePaths(path);
        if (entries != null) {
            String config_ru = path + "config.ru";
            if ( entries.contains(config_ru) ) {
                return config_ru;
            }

            if (level > 0) {
                level--;
                for ( String subpath : entries ) {
                    final int len = subpath.length();
                    if ( len > 0 && subpath.charAt(len - 1) == '/' ) {
                        subpath = findConfigRuPathInSubDirectories(subpath, level);
                        if ( subpath != null ) return subpath;
                    }
                }
            }
        }
        return null;
    }

    private static String getContextLoaderScript(final String name, final boolean silent)
        throws IOException {
        try { // still try context-loader for resolving rackup :
            final ClassLoader contextLoader = Thread.currentThread().getContextClassLoader();
            InputStream is = contextLoader.getResourceAsStream(name);
            return IOHelpers.inputStreamToString(is);
        }
        catch (IOException | RuntimeException e) {
            if ( silent ) return null; throw e;
        }
    }

    private String resolveRackupScript() throws RackInitializationException {
        String rackup = rackContext.getConfig().getRackup();
        if (rackup == null) {
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
                InputStream is;
                try {
                    is = rackContext.getResourceAsStream(rackup);
                    rackupLocation = rackContext.getRealPath(rackup);
                    return this.rackupScript = IOHelpers.inputStreamToString(is);
                }
                catch (IOException e) {
                    try { // last - try context-loader for resolving rackup :
                        if ( (rackup = getContextLoaderScript(rackup, true)) != null ) {
                            return this.rackupScript = rackup;
                        }
                    }
                    catch (IOException ex) { /* won't happen */ }

                    rackContext.log(RackLogger.ERROR, "failed to read rackup from '"+ rackup + "' (" + e + ")");
                    throw new RackInitializationException("failed to read rackup input", e);
                }
            }
            else {
                rackup = "config.ru";
                try {
                    rackup = getContextLoaderScript(rackup, false);
                    rackupLocation = "uri:classloader://config.ru";
                }
                catch (IOException e) {
                    rackContext.log(ERROR, "failed to read rackup from '"+ rackup + "' (" + e + ")");
                    throw new RackInitializationException("failed to read rackup input", e);
                }
            }
        }
        else {
            rackupLocation = "<web.xml>";
        }

        return this.rackupScript = rackup;
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

    private static void setupJRubyManagement() {
        final String jrubyMxEnabled = "jruby.management.enabled";
        if ( ! "false".equalsIgnoreCase( System.getProperty(jrubyMxEnabled) ) ) {
            System.setProperty(jrubyMxEnabled, "true");
        }
    }

}
