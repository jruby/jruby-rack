/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;

import javax.servlet.ServletContext;

public class ServletContextLogger extends RackLogger.Base {

    private final ServletContext context;

    public ServletContextLogger(ServletContext context) {
        this.context = context;
    }

    @Override
    public void log(String message) {
        context.log(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        context.log(message, ex);
    }

    @Override
    public void log(Level level, String message) {
        if ( isEnabled(level) ) context.log(message);
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( isEnabled(level) ) context.log(message, ex);
    }

    @Override
    public boolean isEnabled(Level level) {
        return true;
    }

    @Override
    public Level getLevel() {
        return null; // unknown
    }

}