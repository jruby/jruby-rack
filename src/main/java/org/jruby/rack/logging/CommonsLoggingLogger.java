/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import org.jruby.rack.RackLogger;

public class CommonsLoggingLogger extends RackLogger.Base {

    private Log logger;

    public CommonsLoggingLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public Log getLogger() {
        return logger;
    }

    public void setLogger(Log logger) {
        this.logger = logger;
    }

    public void setLoggerName(String loggerName) {
        logger = LogFactory.getLog(loggerName);
    }

    @Override
    public boolean isEnabled(Level level) {
        if ( level == null ) return logger.isInfoEnabled(); // TODO ???!
        switch ( level ) {
            case DEBUG: return logger.isDebugEnabled();
            case INFO:  return logger.isInfoEnabled();
            case WARN:  return logger.isWarnEnabled();
            case ERROR: return logger.isErrorEnabled();
            case FATAL: return logger.isFatalEnabled();
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
            case FATAL: logger.fatal(message); break;
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
            case FATAL: logger.fatal(message, ex); break;
        }
    }

    @Override
    public Level getLevel() {
        if ( logger.isDebugEnabled() ) return Level.DEBUG;
        if ( logger.isInfoEnabled() )  return Level.INFO ;
        if ( logger.isWarnEnabled() )  return Level.WARN ;
        if ( logger.isErrorEnabled() ) return Level.ERROR;
        if ( logger.isFatalEnabled() ) return Level.FATAL;
        return null;
    }

}
