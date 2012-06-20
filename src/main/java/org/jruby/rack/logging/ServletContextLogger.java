/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;

import javax.servlet.ServletContext;

public class ServletContextLogger implements RackLogger {
    
    private final ServletContext context;

    public ServletContextLogger(ServletContext context) {
        this.context = context;
    }

    public void log(String message) {
        context.log(message);
    }

    public void log(String message, Throwable e) {
        context.log(message, e);
    }
    
    public void log(String level, String message) {
        context.log(level + ": " + message);
    }

    public void log(String level, String message, Throwable e) {
        context.log(level + ": " + message, e);
    }
    
}