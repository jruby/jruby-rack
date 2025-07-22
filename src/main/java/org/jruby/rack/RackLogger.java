/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

/**
 * Abstraction of a logging device.
 * @author nicksieger
 */
public interface RackLogger {
    //void debug(String message) ;
    //void debug(String message, Throwable e) ;

    //void info(String message) ;
    //void info(String message, Throwable e) ;

    //void warn(String message) ;
    //void warn(String message, Throwable e) ;

    //void error(String message) ;
    //void error(String message, Throwable e) ;

    enum Level {
        DEBUG, INFO, WARN, ERROR, FATAL
    }

    boolean isEnabled(final Level level) ;

    void log(Level level, String message) ;
    void log(Level level, String message, Throwable ex) ;

    default void log(String message) {
        log(Level.INFO, message);
    }

    default void log(String message, Throwable ex) {
        log(Level.ERROR, message, ex);
    }

    default void log(String level, String message) {
        log(Level.valueOf(level), message);
    }

    default void log(String level, String message, Throwable ex) {
        log(Level.valueOf(level), message, ex);
    }

    abstract class Base implements RackLogger {
        public abstract Level getLevel() ;
        public void setLevel(Level level) { /* noop */ }

        public boolean isFormatting() { return false; }
        public void setFormatting(boolean flag) { /* noop */ }
    }
}
