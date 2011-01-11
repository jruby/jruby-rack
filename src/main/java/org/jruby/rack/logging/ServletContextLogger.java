/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import javax.servlet.ServletContext;

import org.jruby.rack.RackLogger;

public class ServletContextLogger implements RackLogger {
    private ServletContext context;

    public ServletContextLogger(ServletContext context) {
        this.context = context;
    }

    public void log(String message) {
        context.log(message);
    }

    public void log(String message, Throwable ex) {
        context.log(message, ex);
    }
}