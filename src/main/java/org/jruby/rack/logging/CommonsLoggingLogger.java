/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogConfigurationException;
import org.apache.commons.logging.LogFactory;
import org.jruby.rack.RackLogger;

public class CommonsLoggingLogger implements RackLogger {
    private Log logger;

    public CommonsLoggingLogger() {
        this(RackLoggerFactory.defaultLogName());
    }

    public CommonsLoggingLogger(String loggerName) {
        setLoggerName(loggerName);
    }

    public void setLoggerName(String loggerName) {
        try {
            logger = LogFactory.getLog(loggerName);
        } catch (LogConfigurationException e) {
            throw new LoggerConfigurationException("Unable to configure logger", e);
        }
    }

    @Override
    public void log(String message) {
        logger.info(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        logger.error(message,ex);
    }
}
