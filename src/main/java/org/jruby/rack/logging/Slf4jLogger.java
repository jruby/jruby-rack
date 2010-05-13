/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.jruby.rack.RackLogger;

public class Slf4jLogger implements RackLogger {
    private Logger logger;

    public Slf4jLogger() {
        this(RackLoggerFactory.defaultLogName());
    }

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
