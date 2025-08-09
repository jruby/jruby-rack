/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Slf4jLogger extends RackLogger.Base {

    private Logger logger;

    public Slf4jLogger() {
        setLoggerName("");
    }

    public Slf4jLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public Logger getLogger() {
        return logger;
    }

    public void setLogger(Logger logger) {
        this.logger = logger;
    }

    public void setLoggerName(String loggerName) {
        logger = LoggerFactory.getLogger(loggerName);
    }

    @Override
    public boolean isEnabled(Level level) {
        if ( level == null ) return logger.isInfoEnabled(); // TODO ???!
        return switch (level) {
            case DEBUG -> logger.isDebugEnabled();
            case INFO -> logger.isInfoEnabled();
            case WARN -> logger.isWarnEnabled();
            case ERROR, FATAL -> logger.isErrorEnabled();
        };
    }

    @Override
    public void log(Level level, CharSequence message) {
        if ( level == null ) { logger.info(message.toString()); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message.toString()); break;
            case INFO:  logger.info(message.toString()); break;
            case WARN:  logger.warn(message.toString()); break;
            case ERROR, FATAL: logger.error(message.toString()); break;
        }
    }

    @Override
    public void log(Level level, CharSequence message, Throwable ex) {
        if ( level == null ) { logger.error(message.toString(), ex); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message.toString(), ex); break;
            case INFO:  logger.info(message.toString(), ex); break;
            case WARN:  logger.warn(message.toString(), ex); break;
            case ERROR, FATAL: logger.error(message.toString(), ex); break;
        }
    }

    @Override
    public Level getLevel() {
        if ( logger.isDebugEnabled() ) return Level.DEBUG;
        if ( logger.isInfoEnabled() )  return Level.INFO ;
        if ( logger.isWarnEnabled() )  return Level.WARN ;
        if ( logger.isErrorEnabled() ) return Level.ERROR;
        if ( logger.isErrorEnabled() ) return Level.FATAL;
        return null;
    }

}
