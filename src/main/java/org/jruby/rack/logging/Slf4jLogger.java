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
        switch ( level ) {
            case DEBUG: return logger.isDebugEnabled();
            case INFO:  return logger.isInfoEnabled();
            case WARN:  return logger.isWarnEnabled();
            case ERROR: return logger.isErrorEnabled();
            case FATAL: return logger.isErrorEnabled();
        }
        return logger.isTraceEnabled();
    }

    @Override
    public void log(Level level, String message) {
        if ( level == null ) { logger.info(message); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message); break;
            case INFO:  logger.info(message); break;
            case WARN:  logger.warn(message); break;
            case ERROR: logger.error(message); break;
            case FATAL: logger.error(message); break;
        }
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( level == null ) { logger.error(message, ex); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message, ex); break;
            case INFO:  logger.info(message, ex); break;
            case WARN:  logger.warn(message, ex); break;
            case ERROR: logger.error(message, ex); break;
            case FATAL: logger.error(message, ex); break;
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
