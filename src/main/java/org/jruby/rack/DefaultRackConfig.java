/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.CompatVersion;
import org.jruby.rack.logging.StandardOutLogger;
import org.jruby.util.SafePropertyAccessor;

import java.lang.reflect.Constructor;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Base implementation of RackConfig that retrieves settings from system properties.
 */
public class DefaultRackConfig implements RackConfig {
    private static final Pattern COMPAT_VERSION = Pattern.compile("1[._]([89])");
    private static final Map<String,String> loggerTypes = Collections.unmodifiableMap(new HashMap<String, String>() {{
        put("commons_logging", "org.jruby.rack.logging.CommonsLoggingLogger");
        put("clogging", "org.jruby.rack.logging.CommonsLoggingLogger");
        put("slf4j", "org.jruby.rack.logging.Slf4jLogger");
        put("log4j", "org.jruby.rack.logging.Log4jLogger");
        put("servlet_context", "org.jruby.rack.logging.ServletContextLogger");
        put("stdout", "org.jruby.rack.logging.StandardOutLogger");
    }});

    private RackLogger logger;
    private boolean quiet = false;

    public CompatVersion getCompatVersion() {
        String versionString = getProperty("jruby.compat.version");
        if (versionString != null) {
            Matcher matcher = COMPAT_VERSION.matcher(versionString);
            if (matcher.find()) {
                String version = matcher.group(1);
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
        return getPositiveInteger("jruby.runtime.timeout.sec");
    }

    public String[] getRuntimeArguments() {
        final String args = getProperty("jruby.runtime.arguments");
        return args == null ? null : args.trim().split("\\s+");
    }
    
    public Integer getNumInitializerThreads() {
        return getPositiveInteger("jruby.runtime.initializer.threads");
    }

    public RackLogger getLogger() {
        if (logger == null) {
            String loggerClass = getLoggerClassName();
            if (loggerTypes.containsKey(loggerClass)) {
                loggerClass = loggerTypes.get(loggerClass);
            }

            logger = createLogger(loggerClass);
        }
        return logger;
    }

    protected RackLogger createLogger(String loggerClass) {
        try {
            final Class<?> c = Class.forName(loggerClass);
            try {
                Constructor<?> ctor = c.getConstructor(new Class<?>[] { String.class });
                return (RackLogger) ctor.newInstance(new Object[] { getLoggerName() });
            } catch (Exception tryAgain) {
                return (RackLogger) c.newInstance();
            }
        } catch (Exception e) {
            if (!quiet) {
                System.err.println("Error loading logger: " + loggerClass);
                e.printStackTrace(System.err);
            }
            return new StandardOutLogger(null);
        }
    }

    public boolean isFilterAddsHtml() {
        return getBoolean("jruby.rack.filter.adds.html", true);
    }

    public boolean isFilterVerifiesResource() {
        return getBoolean("jruby.rack.filter.verifies.resource", false);
    }

    public String getJmsConnectionFactory() {
        return getProperty("jms.connection.factory");
    }

    public String getJmsJndiProperties() {
        return getProperty("jms.jndi.properties");
    }

    public boolean isSerialInitialization() {
        return getBoolean("jruby.init.serial", false);
    }

    public String getLoggerName() {
        return getProperty("jruby.rack.logging.name", "jruby.rack");
    }

    public String getLoggerClassName() {
        return getProperty("jruby.rack.logging", "servlet_context");
    }

    public Integer getInitialRuntimes() {
        return getRangeValue("min", "minIdle");
    }

    public Integer getMaximumRuntimes() {
        return getRangeValue("max", "maxActive");
    }

    public boolean isRewindable() {
        return getBoolean("jruby.rack.input.rewindable", true);
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
        return getBoolean("jruby.rack.ignore.env", false);
    }

    public String getProperty(String key) {
        return getProperty(key, null);
    }

    public String getProperty(String key, String defaultValue) {
        return SafePropertyAccessor.getProperty(key, defaultValue);
    }

    public boolean isQuiet() {
        return quiet;
    }

    public void setQuiet(boolean quiet) {
        this.quiet = quiet;
    }

    private Integer getRangeValue(String end, String gsValue) {
        Integer v = getPositiveInteger("jruby." + end + ".runtimes");
        if (v == null) {
            v = getPositiveInteger("jruby.pool." + gsValue);
        }
        if (v == null) {
            getLogger().log("Warning: no " + end + " runtimes specified.");
        } else {
            getLogger().log("Info: received " + end + " runtimes = " + v);
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

    private boolean getBoolean(String key, boolean defValue) {
        final String value = getProperty(key);
        if (value == null) return defValue;
        try {
            return Boolean.parseBoolean(value);
        } catch (Exception e) { /* ignored */ }
        return defValue;
    }
    
}
