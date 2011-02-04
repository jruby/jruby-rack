/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.DefaultRackConfig;
import org.jruby.rack.RackLogger;
import org.jruby.rack.logging.ServletContextLogger;

import javax.servlet.ServletContext;

/**
 * Servlet environment version of RackConfig.
 */
public class ServletRackConfig extends DefaultRackConfig {

    private ServletContext context;

    public ServletRackConfig(ServletContext context) {
        this.context = context;
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
    protected RackLogger createLogger(String loggerClass) {
        if (loggerClass == null || loggerClass.equals(ServletContextLogger.class.getName())) {
            return new ServletContextLogger(context);
        }
        return super.createLogger(loggerClass);
    }

    public ServletContext getServletContext() {
        return context;
    }
}
