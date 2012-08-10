/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.CompatVersion;
import org.jruby.rack.logging.OutputStreamLogger;
import org.jruby.rack.logging.StandardOutLogger;
import org.jruby.util.SafePropertyAccessor;

import java.io.PrintStream;
import java.io.OutputStream;
import java.lang.reflect.Constructor;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Base implementation of RackConfig that retrieves settings from system properties.
 */
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
        String versionString = getProperty("jruby.compat.version");
        if (versionString != null) {
            final Pattern pattern = Pattern.compile("1[._]([89])");
            final Matcher matcher = pattern.matcher(versionString);
            if (matcher.find()) {
                final String version = matcher.group(1);
                if (version.equals("8")) {
                    return CompatVersion.RUBY1_8;
                } else if (version.equals("9")) {
                    return CompatVersion.RUBY1_9;
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

    public boolean isIgnoreEnvironment() {
        return getBooleanProperty("jruby.rack.ignore.env", false);
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
    
    protected static Boolean toBoolean(String value, Boolean defaultValue) {
        if (value == null) return defaultValue;
        try {
            return Boolean.valueOf(value);
        } 
        catch (Exception e) { /* ignored */ }
        return defaultValue;
    }

    protected static Number toNumber(String value, Number defaultValue) {
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
