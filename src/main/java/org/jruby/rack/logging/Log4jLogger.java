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

public class Log4jLogger implements RackLogger {
    private Logger logger;

    public Log4jLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public void setLoggerName(String loggerName) {
        logger = Logger.getLogger(loggerName);
    }

    public void log(String message) {
        logger.info(message);
    }

    public void log(String message, Throwable ex) {
        logger.error(message, ex);
    }
}
