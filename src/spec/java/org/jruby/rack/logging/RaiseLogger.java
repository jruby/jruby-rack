/*
 * The MIT License
 *
 * Copyright (c) 2014 Karol Bucek LTD.
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

import java.io.PrintStream;

import org.jruby.rack.RackLogger;

/**
 *
 * @author kares
 */
public class RaiseLogger extends RackLogger.Base {

    final PrintStream out;
    final PrintStream err;

    private boolean enabled;
    private Level level = Level.WARN;

    public RaiseLogger() {
        this((Level) null);
    }

    public RaiseLogger(final Level level) {
        this(System.out, System.err);
        this.level = level;
    }

    public RaiseLogger(final String level, final PrintStream out) {
        this(out, out);
        this.level = Level.valueOf(level);
    }

    public RaiseLogger(final PrintStream out) {
        this(out, out);
    }

    public RaiseLogger(final PrintStream out, final PrintStream err) {
        this.out = out; this.err = err;
    }

    public Level getRaiseLevel() {
        return level;
    }

    public void setRaiseLevel(Level level) {
        this.level = level;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    @Override
    public boolean isEnabled(final Level level) {
        return this.enabled;
    }

    private boolean isRaise(final Level level) {
        return this.level.ordinal() <= level.ordinal();
    }

    @Override
    public void log(Level level, String message) {
        if ( isEnabled(level) ) {
            out.println(level + " : " + message);
        }
        if ( isRaise(level) ) {
            throw new RuntimeException(message);
        }
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( isEnabled(level) ) {
            if ( level.ordinal() >= Level.ERROR.ordinal() ) {
               err.println(level + " : " + message);
               ex.printStackTrace(err);
            }
            else {
               out.println(level + " : " + message);
               ex.printStackTrace(out);
            }
        }
        if ( isRaise(level) ) {
            if ( ex instanceof RuntimeException ) throw (RuntimeException) ex;
            throw new RuntimeException(message, ex);
        }
    }

}
