/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;

import jakarta.servlet.ServletContext;

public class ServletContextLogger extends RackLogger.Base {

    private final ServletContext context;

    public ServletContextLogger(ServletContext context) {
        this.context = context;
    }

    @Override
    public void log(CharSequence message) {
        context.log(message.toString());
    }

    @Override
    public void log(CharSequence message, Throwable ex) {
        context.log(message.toString(), ex);
    }

    @Override
    public void log(Level level, CharSequence message) {
        if ( isEnabled(level) ) context.log(message.toString());
    }

    @Override
    public void log(Level level, CharSequence message, Throwable ex) {
        if ( isEnabled(level) ) context.log(message.toString(), ex);
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