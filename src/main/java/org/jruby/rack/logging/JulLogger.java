/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import java.util.logging.Level;
import java.util.logging.Logger;

import org.jruby.rack.RackLogger;

/**
 * java.util.logging based logger implementation
 * 
 * @see Logger
 * @author kares
 */
public class JulLogger implements RackLogger {
    
    private Logger logger;

    public JulLogger() {
        setLoggerName(""); // "" - root logger name
    }

    public JulLogger(String loggerName) {
        setLoggerName(loggerName);
    }
    
    public void setLoggerName(String loggerName) {
        logger = Logger.getLogger(loggerName);
    }

    public void log(String message) {
        logger.log( Level.INFO, message );
    }

    public void log(String message, Throwable e) {
        logger.log( Level.SEVERE, message, e );
    }
    
    public void log(String level, String message) {
        logger.log( mapLevel(level, Level.INFO), message );
    }

    public void log(String level, String message, Throwable e) {
        logger.log( mapLevel(level, Level.SEVERE), message, e );
    }
    
    private static Level mapLevel(String level, Level defaultLevel) {
        if ( level == ERROR ) return Level.SEVERE;
        if ( level == WARN )  return Level.WARNING;
        if ( level == INFO )  return Level.INFO;
        if ( level == DEBUG ) return Level.FINE;
        return defaultLevel;
    }
    
}
