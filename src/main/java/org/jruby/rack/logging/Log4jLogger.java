/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2011 ThoughtWorks, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;
import org.apache.log4j.Logger;

import static org.jruby.rack.RackLogger.Level.ERROR;

public class Log4jLogger extends RackLogger.Base {

    private Logger logger;

    public Log4jLogger() {
        logger = Logger.getRootLogger();
    }

    public Log4jLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public Logger getLogger() {
        return logger;
    }

    public void setLogger(Logger logger) {
        this.logger = logger;
    }

    public void setLoggerName(String loggerName) {
        logger = Logger.getLogger(loggerName);
    }

    @Override
    public boolean isEnabled(Level level) {
        if ( level == null ) return logger.isInfoEnabled(); // TODO ???!
        switch ( level ) {
            case DEBUG: return logger.isDebugEnabled();
            case INFO:  return logger.isInfoEnabled();
            case WARN:  return logger.isEnabledFor(org.apache.log4j.Level.WARN);
            case ERROR: return logger.isEnabledFor(org.apache.log4j.Level.ERROR);
            case FATAL: return logger.isEnabledFor(org.apache.log4j.Level.FATAL);
        }
        return logger.isEnabledFor(org.apache.log4j.Level.ALL);
    }

    @Override
    public void log(Level level, String message) {
        if ( level == null ) { logger.info(message); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message);
            case INFO:  logger.info(message);
            case WARN:  logger.warn(message);
            case ERROR: logger.error(message);
            case FATAL: logger.fatal(message);
        }
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( level == null ) { logger.error(message, ex); return; }
        switch ( level ) {
            case DEBUG: logger.debug(message, ex);
            case INFO:  logger.info(message, ex);
            case WARN:  logger.warn(message, ex);
            case ERROR: logger.error(message, ex);
            case FATAL: logger.fatal(message, ex);
        }
    }

}
