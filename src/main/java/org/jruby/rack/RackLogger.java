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
    enum Level {
        DEBUG, INFO, WARN, ERROR, FATAL
    }

    boolean isEnabled(final Level level) ;

    void log(Level level, CharSequence message) ;

    void log(Level level, CharSequence message, Throwable ex) ;

    default void log(CharSequence message) {
        log(Level.INFO, message);
    }

    default void log(CharSequence message, Throwable ex) {
        log(Level.ERROR, message, ex);
    }

    @Deprecated
    default void log(Level level, String message) {
        log(level, (CharSequence) message);
    }

    @Deprecated
    default void log(Level level, String message, Throwable ex) {
        log(level, (CharSequence) message, ex);
    }

    abstract class Base implements RackLogger {
        public abstract Level getLevel() ;
        public void setLevel(Level level) { /* noop */ }

        public boolean isFormatting() { return false; }
        public void setFormatting(boolean flag) { /* noop */ }
    }
}
