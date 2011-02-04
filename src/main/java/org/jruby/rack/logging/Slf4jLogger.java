/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Slf4jLogger implements RackLogger {
    private Logger logger;

    public Slf4jLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public void setLoggerName(String loggerName) {
        logger = LoggerFactory.getLogger(loggerName);
    }

    @Override
    public void log(String message) {
        logger.info(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        logger.error(message, ex);
    }
}
