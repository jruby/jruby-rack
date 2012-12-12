/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.io.LineNumberReader;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.StringReader;
import java.lang.reflect.Constructor;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.jruby.CompatVersion;
import org.jruby.rack.logging.OutputStreamLogger;
import org.jruby.rack.logging.StandardOutLogger;
import org.jruby.util.SafePropertyAccessor;

/**
 * A base implementation of that retrieves settings from system properties.
 * 
 * @see System#getProperty(String) 
 * @see RackConfig
 */
@SuppressWarnings("deprecation")
public class DefaultRackConfig implements RackConfig {

    private RackLogger logger;
    private boolean quiet = false;
    private PrintStream out = System.out;
    private PrintStream err = System.err;

    public PrintStream getOut() {
        return out;
    }

    public void setOut(OutputStream o) {
        if (o == null) {
            out = System.out;
        } else if (o instanceof PrintStream) {
            out = (PrintStream) o;
        } else {
            out = new PrintStream(o);
        }
    }

    public PrintStream getErr() {
        return err;
    }

    public void setErr(OutputStream o) {
        if (o == null) {
            err = System.err;
        } else if (o instanceof PrintStream) {
            err = (PrintStream) o;
        } else {
            err = new PrintStream(o);
        }
    }

    public boolean isQuiet() {
        return quiet;
    }

    public void setQuiet(boolean quiet) {
        this.quiet = quiet;
    }
    
    public CompatVersion getCompatVersion() {
        final String version = getProperty("jruby.compat.version");
        if ( version != null ) {
            // we handle 1.8, RUBY1_9, --2.0m 1_9 etc :
            final Pattern pattern = Pattern.compile("([12])[._]([890])");
            final Matcher matcher = pattern.matcher(version);
            if ( matcher.find() ) {
                final String name = "RUBY" + 
                    matcher.group(1) + '_' + matcher.group(2);
                try {
                    return Enum.valueOf(CompatVersion.class, name);
                }
                catch (IllegalArgumentException e) {
                    getLogger().log(RackLogger.WARN, 
                        "could not resolve compat version from '"+ version +"' will use default", e);
                }
            }
        }
        return null;
    }

    public String getRackup() {
        return getProperty("rackup");
    }

    public String getRackupPath() {
        return getProperty("rackup.path");
    }

    public Integer getRuntimeTimeoutSeconds() {
        Integer timeout = getPositiveInteger("jruby.runtime.acquire.timeout");
        if (timeout == null) { // backwards compatibility with 1.0.x :
            timeout = getPositiveInteger("jruby.runtime.timeout.sec");
        }
        return timeout;
    }

    public String[] getRuntimeArguments() {
        final String args = getProperty("jruby.runtime.arguments");
        return args == null ? null : args.trim().split("\\s+");
    }

    public Integer getNumInitializerThreads() {
        Number threads = getNumberProperty("jruby.runtime.init.threads");
        if (threads == null) { // backwards compatibility with 1.0.x :
            threads = getNumberProperty("jruby.runtime.initializer.threads");
        }
        return threads != null ? threads.intValue() : null;
    }

    public boolean isSerialInitialization() {
        Boolean serial = getBooleanProperty("jruby.runtime.init.serial");
        if (serial == null) { // backwards compatibility with 1.0.x :
            serial = getBooleanProperty("jruby.init.serial");
            
            if (serial == null) { // if initializer threads set to <= 0
                Integer threads = getNumInitializerThreads();
                if ( threads != null && threads < 0 ) {
                    serial = Boolean.TRUE;
                }
                else {
                    serial = Boolean.FALSE;
                }
            }
        }
        return serial.booleanValue();
    }
    
    public RackLogger getLogger() {
        if (logger == null) {
            String loggerClass = getLoggerClassName();
            if ( "stdout".equalsIgnoreCase(loggerClass) ) {
                logger = new OutputStreamLogger(getOut());
            }
            else if ( "stderr".equalsIgnoreCase(loggerClass) ) {
                logger = new OutputStreamLogger(getErr());
            }
            else {
                final Map<String, String> loggerTypes = getLoggerTypes();
                final String loggerKey = loggerClass.toLowerCase();
                if (loggerTypes.containsKey(loggerKey)) {
                    loggerClass = loggerTypes.get(loggerKey);
                }
                logger = createLogger(loggerClass);
            }
            if (logger == null) logger = defaultLogger();
        }
        return logger;
    }

    protected RackLogger createLogger(final String loggerClass) {
        try {
            final Class<?> klass = Class.forName(loggerClass);
            try {
                Constructor<?> ctor = klass.getConstructor(new Class<?>[] { String.class });
                return (RackLogger) ctor.newInstance(new Object[] { getLoggerName() });
            } catch (Exception tryAgain) {
                return (RackLogger) klass.newInstance();
            }
        } catch (Exception e) {
            if ( ! isQuiet() ) {
                err.println("Failed loading logger: " + loggerClass);
                e.printStackTrace(err);
            }
            return null;
        }
    }
    
    protected RackLogger defaultLogger() {
        return new StandardOutLogger(getOut());
    }
    
    public boolean isFilterAddsHtml() {
        return getBooleanProperty("jruby.rack.filter.adds.html", true);
    }

    public boolean isFilterVerifiesResource() {
        return getBooleanProperty("jruby.rack.filter.verifies.resource", false);
    }

    public String getJmsConnectionFactory() {
        return getProperty("jms.connection.factory");
    }

    public String getJmsJndiProperties() {
        return getProperty("jms.jndi.properties");
    }

    public String getLoggerName() {
        return getProperty("jruby.rack.logging.name", "jruby.rack");
    }

    public String getLoggerClassName() {
        return getProperty("jruby.rack.logging", "servlet_context");
    }

    public Integer getInitialRuntimes() {
        return getRuntimesRangeValue("min", "minIdle");
    }

    public Integer getMaximumRuntimes() {
        return getRuntimesRangeValue("max", "maxActive");
    }

    public boolean isRewindable() {
        return getBooleanProperty("jruby.rack.input.rewindable", true);
    }

    public Integer getInitialMemoryBufferSize() {
        return getPositiveInteger("jruby.rack.request.size.initial.bytes");
    }

    public Integer getMaximumMemoryBufferSize() {
        Integer max = getPositiveInteger("jruby.rack.request.size.maximum.bytes");
        if (max == null) { // backwards compatibility with 1.0.x :
            max = getPositiveInteger("jruby.rack.request.size.threshold.bytes");
        }
        return max;
    }
    
    public Map<String, String> getRuntimeEnvironment() {
        String env = getProperty("jruby.runtime.env");
        if ( env == null ) env = getProperty("jruby.runtime.environment");
        final Object envFlag = toStrictBoolean(env, null);
        if ( envFlag != null ) {
            boolean keep = ((Boolean) envFlag).booleanValue();
            // jruby.runtime.env = true keep as is (return null)
            // jruby.runtime.env = false clear env (return empty)
            //return keep ? null : new HashMap<String, String>();
            if ( keep ) {
                return new HashMap<String, String>(System.getenv());
            }
            else {
                return new HashMap<String, String>();
            }
        }
        if ( isIgnoreEnvironment() ) return new HashMap<String, String>();
        // TODO maybe support custom value 'servlet' to use init params ?
        return toStringMap(env);
    }

    // NOTE: this is only here to be able to maintain previous behavior
    // jruby.rack.ignore.env did ENV.clear but after RUBYOPT has been processed
    static boolean isIgnoreRUBYOPT(RackConfig config) {
        // RUBYOPT ignored if jruby.runtime.env.rubyopt = false
        Boolean rubyopt = config.getBooleanProperty("jruby.runtime.env.rubyopt");
        if ( rubyopt == null ) return ! config.isIgnoreEnvironment();
        return rubyopt != null && ! rubyopt.booleanValue();
    }
    
    public boolean isIgnoreEnvironment() {
        return getBooleanProperty("jruby.rack.ignore.env", false);
    }
    
    public boolean isThrowInitException() {
        return isThrowInitException(this);
    }
    
    static boolean isThrowInitException(RackConfig config) {
        Boolean error = config.getBooleanProperty("jruby.rack.error");
        if ( error != null && ! error.booleanValue() ) {
            return true; // jruby.rack.error = false
        }
        error = config.getBooleanProperty("jruby.rack.exception");
        if ( error != null && ! error.booleanValue() ) {
            return true; // jruby.rack.exception = false
        }
        return false;
    }
    
    public String getProperty(String key) {
        return getProperty(key, null);
    }

    public String getProperty(String key, String defaultValue) {
        return SafePropertyAccessor.getProperty(key, defaultValue);
    }

    public Boolean getBooleanProperty(String key) {
        return getBooleanProperty(key, null);
    }
    
    public Boolean getBooleanProperty(String key, Boolean defaultValue) {
        return toBoolean(getProperty(key), defaultValue);
    }

    public Number getNumberProperty(String key) {
        return getNumberProperty(key, null);
    }
    
    public Number getNumberProperty(String key, Number defaultValue) {
        return toNumber(getProperty(key), defaultValue);
    }
    
    private Integer getRuntimesRangeValue(String end, String gsValue) {
        Integer v = getPositiveInteger("jruby." + end + ".runtimes");
        if (v == null) {
            v = getPositiveInteger("jruby.pool." + gsValue);
        }
        return v;
    }

    private Integer getPositiveInteger(String key) {
        final String value = getProperty(key);
        if (value == null) return null;
        try {
            int i = Integer.parseInt(value);
            if (i > 0) return Integer.valueOf(i);
        } catch (Exception e) { /* ignored */ }
        return null;
    }
    
    public static Boolean toBoolean(String value, Boolean defaultValue) {
        if (value == null) return defaultValue;
        try {
            return Boolean.valueOf(value);
        } 
        catch (Exception e) { /* ignored */ }
        return defaultValue;
    }

    public static Object toStrictBoolean(String value, Object defaultValue) {
        if ( "true".equalsIgnoreCase(value) ) return Boolean.TRUE;
        if ( "false".equalsIgnoreCase(value) ) return Boolean.FALSE;
        return defaultValue;
    }
    
    public static Number toNumber(String value, Number defaultValue) {
        if (value == null) return defaultValue;
        try {
            float number = Float.parseFloat(value);
            if ( Float.isInfinite(number) ) {
                return Double.parseDouble(value);
            }
            if ( Float.isNaN(number) ) {
                return defaultValue;
            }
            if ( number == ((int) number) )
            if ( number > Integer.MAX_VALUE ) {
                return Long.valueOf((long) number);
            }
            else {
                return Integer.valueOf((int) number);
            }
            return Float.valueOf(number);
        }
        catch (Exception e) { /* ignored */ }
        return defaultValue;
    }
    
    private Map<String, String> toStringMap(final String env) {
        if ( env == null ) return null;
        /*
          USER=kares,TERM=xterm,SHELL=/bin/bash
          PATH=/opt/local/rvm/gems/jruby-1.6.8@jruby-rack/bin:/opt/local/rvm/gems/jruby-1.6.8@global/bin
          GEM_HOME=/opt/local/rvm/gems/jruby-1.6.8@jruby-rack
         */
        LineNumberReader reader = new LineNumberReader(new StringReader(env.trim()));
        Map<String, String> map = new LinkedHashMap<String, String>(); String line;
        try {
            while ( (line = reader.readLine()) != null ) {
                final String[] entries = line.split(",");
                String lastKey = null, lastVal = null;
                for ( final String entry : entries ) {
                    String[] pair = entry.split("=", 2);
                    if ( pair.length == 1 ) { // no = separator
                        if ( entry.trim().length() == 0 ) continue;
                        if ( lastKey == null ) continue; // missing key
                        map.put( lastKey, lastVal = lastVal + ',' + entry );
                    }
                    else {
                        map.put( lastKey = pair[0], lastVal = pair[1] );
                    }
                }
            }
        }
        catch (IOException e) {
            if ( ! isQuiet() ) {
                err.println("Failed parsing env: \n" + env);
                e.printStackTrace(err);
            }
        }
        return map;
    }
    
    private static Map<String,String> getLoggerTypes() {
        final Map<String,String> loggerTypes = new HashMap<String, String>();
        loggerTypes.put("commons_logging", "org.jruby.rack.logging.CommonsLoggingLogger");
        loggerTypes.put("clogging", "org.jruby.rack.logging.CommonsLoggingLogger");
        loggerTypes.put("log4j", "org.jruby.rack.logging.Log4jLogger");
        loggerTypes.put("slf4j", "org.jruby.rack.logging.Slf4jLogger");
        loggerTypes.put("jul", "org.jruby.rack.logging.JulLogger");
        loggerTypes.put("servlet_context", "org.jruby.rack.logging.ServletContextLogger");
        return loggerTypes;
    }
    
}
