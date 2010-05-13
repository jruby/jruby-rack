/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import javax.servlet.ServletContext;

import org.jruby.rack.RackLogger;
import org.jruby.util.SafePropertyAccessor;
import java.util.Map;
import java.util.HashMap;
import java.util.Collections;

public class RackLoggerFactory {
    private static final String LOGGING_KEY = "jruby.rack.logging";
    private static final Map<String,String> loggerTypes = Collections.unmodifiableMap(new HashMap<String,String>() {{
        put("commons_logging", "org.jruby.rack.logging.CommonsLoggingLogger");
        put("clogging",        "org.jruby.rack.logging.CommonsLoggingLogger");
        put("slf4j",           "org.jruby.rack.logging.Slf4jLogger");
        put("servlet_context", "org.jruby.rack.logging.ServletContextLogger");
        put("stdout",          "org.jruby.rack.logging.StandardOutLogger");
    }});

    private final boolean quiet;

    public RackLoggerFactory(boolean quiet) {
        this.quiet = quiet;
    }

    public RackLoggerFactory() {
        this(false);
    }

    public static final String defaultLogName() {
        return SafePropertyAccessor.getProperty(LOGGING_KEY + ".name", "jruby.rack");
    }

    public RackLogger getLogger(ServletContext context) {
        String loggerClass = context.getInitParameter(LOGGING_KEY);

        if (loggerClass == null) {
            loggerClass = SafePropertyAccessor.getProperty(LOGGING_KEY, "servlet_context");
        }

        if (loggerTypes.containsKey(loggerClass)) {
            loggerClass = loggerTypes.get(loggerClass);
        }

        RackLogger logger;
        try {
            Class c = Class.forName(loggerClass);
            if (c.equals(ServletContextLogger.class)) {
                logger = new ServletContextLogger(context);
            } else {
                logger = (RackLogger) c.newInstance();
            }
        } catch (Exception e) {
            if (!quiet) {
                System.err.println("Error loading logger: " + loggerClass);
                e.printStackTrace(System.err);
            }
            logger = new StandardOutLogger();
        }
        return logger;
    }
}
