/*
 * The MIT License
 *
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package org.jruby.rack.logging;

import java.util.logging.Logger;

import org.jruby.rack.RackLogger;

/**
 * java.util.logging based logger implementation
 *
 * @see Logger
 * @author kares
 */
public class JulLogger extends RackLogger.Base {

    private Logger logger;

    public JulLogger() {
        setLoggerName(""); // "" - root logger name
    }

    public JulLogger(String loggerName) {
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
        if ( level == null ) return logger.isLoggable(java.util.logging.Level.INFO); // TODO ???!
        return logger.isLoggable(mapLevel(level, java.util.logging.Level.ALL));
    }

    @Override
    public void log(Level level, CharSequence message) {
        logger.log( mapLevel(level, java.util.logging.Level.INFO), message.toString() );
    }

    @Override
    public void log(Level level, CharSequence message, Throwable e) {
        logger.log( mapLevel(level, java.util.logging.Level.SEVERE), message.toString(), e );
    }

    private static java.util.logging.Level mapLevel(
        final Level level, java.util.logging.Level defaultLevel) {
        if ( level == null ) { return defaultLevel; }
        return switch (level) {
            case DEBUG -> java.util.logging.Level.FINE;
            case INFO -> java.util.logging.Level.INFO;
            case WARN -> java.util.logging.Level.WARNING;
            case ERROR, FATAL -> java.util.logging.Level.SEVERE;
        };
    }

    @Override
    public Level getLevel() {
        if ( logger.isLoggable(java.util.logging.Level.FINE) ) return Level.DEBUG;
        if ( logger.isLoggable(java.util.logging.Level.INFO) ) return Level.INFO ;
        if ( logger.isLoggable(java.util.logging.Level.WARNING) ) return Level.WARN ;
        if ( logger.isLoggable(java.util.logging.Level.SEVERE) ) return Level.ERROR;
        if ( logger.isLoggable(java.util.logging.Level.SEVERE) ) return Level.FATAL;
        return null;
    }

}
