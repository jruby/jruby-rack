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

import java.io.OutputStream;
import java.io.PrintStream;

import org.jruby.rack.RackLogger;

/**
 *
 * @author kares
 */
public class OutputStreamLogger extends RackLogger.Base {

    private final PrintStream out;
    private Level level;

    public OutputStreamLogger(OutputStream out) {
        this(new PrintStream(out));
    }

    public OutputStreamLogger(PrintStream out) {
        if ( out == null ) {
            throw new IllegalArgumentException("no stream");
        }
        this.out = out;
    }

    public Level getLevel() {
        return level;
    }

    public void setLevel(Level level) {
        this.level = level;
    }

    @Override
    public void log(String message) {
        doLog(message); // log(Level.INFO, message);
    }

    @Override
    public void log(String message, Throwable ex) {
        doLog(message, ex); // log(Level.ERROR, message, ex);
    }

    @Override
    public void log(Level level, String message) {
        if ( ! isEnabled(level) ) return;
        out.print(level); out.print(": ");
        doLog(message);
    }

    private void doLog(final CharSequence message) {
        printMessage(out, message);
        out.flush();
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( ! isEnabled(level) ) return;
        out.print(level); out.print(": ");
        doLog(message, ex);
    }

    private void doLog(final String message, final Throwable ex) {
        printMessage(out, message);
        ex.printStackTrace(out);
        out.flush();
    }

    @Override
    public boolean isEnabled(final Level level) {
        if ( level == null || this.level == null ) return true;
        return this.level.ordinal() <= level.ordinal();
    }

    public static void printMessage(final PrintStream out, final CharSequence message) {
        if ( message.charAt(message.length() - 1) == '\n' ) {
            out.print(message);
        }
        else {
            out.println(message);
        }
    }

}