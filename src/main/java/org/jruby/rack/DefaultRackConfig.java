package org.jruby.rack;

import org.jruby.CompatVersion;
import org.jruby.rack.input.RackRewindableInput;
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
            Class<?> c = Class.forName(loggerClass);
            try {
                Constructor<?> ctor = c.getConstructor(new Class<?>[] {String.class});
                return (RackLogger) ctor.newInstance(new Object[] {getLoggerName()});
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

    public boolean isSlashIndex() {
        return getBoolean("jruby.rack.slash.index", false);
    }

    public boolean isBackgroundSpooling() {
        return getBoolean("jruby.rack.background.spool", false);
    }

    public String getJmsConnectionFactory() {
        return getProperty("jms.connection.factory");
    }

    public String getJmsJndiProperties() {
        return getProperty("jms.jndi.properties");
    }

    public int getMemoryBufferSize() {
        Integer i = getPositiveInteger("jruby.rack.request.size.threshold.bytes");
        if (i == null) {
            i = RackRewindableInput.getDefaultThreshold();
        }
        return i;
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

    private Integer getPositiveInteger(String string) {
        try {
            int i = Integer.parseInt(getProperty(string));
            if (i > 0) {
                return new Integer(i);
            }
        } catch (Exception e) {
        }
        return null;
    }

    private boolean getBoolean(String key, boolean defValue) {
        try {
            return Boolean.parseBoolean(getProperty(key));
        } catch (Exception e) {
        }
        return defValue;
    }
}
