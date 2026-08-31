/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import jakarta.servlet.ServletContext;
import org.jruby.rack.DefaultRackConfig;
import org.jruby.rack.RackLogger;
import org.jruby.rack.logging.ServletContextLogger;

/**
 * Servlet environment version of RackConfig.
 */
public class ServletRackConfig extends DefaultRackConfig {

    private final ServletContext context;

    public ServletRackConfig(ServletContext context) {
        this.context = context;
    }

    public ServletContext getServletContext() {
        return context;
    }

    @Override
    public String getProperty(String key) {
        String value;
        if ((value = context.getInitParameter(key)) != null) {
            return value;
        }
        return super.getProperty(key);
    }

    @Override
    public String getProperty(String key, String defaultValue) {
        String value;
        if ((value = context.getInitParameter(key)) != null) {
            return value;
        }
        return super.getProperty(key, defaultValue);
    }

    @Override
    protected String defaultLoggerClassName() { return "servlet_context"; }

    @Override
    protected RackLogger createLogger(String loggerClass) {
        if (loggerClass == null ||
            "servlet_context".equalsIgnoreCase(loggerClass) ||
            ServletContextLogger.class.getName().equals(loggerClass)) {
            return new ServletContextLogger(context);
        }
        return super.createLogger(loggerClass);
    }

    @Override
    protected RackLogger defaultLogger() {
        return new ServletContextLogger(context);
    }

}
