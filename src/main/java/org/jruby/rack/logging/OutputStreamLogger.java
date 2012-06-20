/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import java.io.OutputStream;
import java.io.PrintStream;

import org.jruby.rack.RackLogger;

/**
 *
 * @author kares
 */
public class OutputStreamLogger implements RackLogger {
 
    private final PrintStream out;

    public OutputStreamLogger(OutputStream out) {
        this(new PrintStream(out));
    }
    
    public OutputStreamLogger(PrintStream out) {
        if (out == null) {
            throw new IllegalArgumentException("no out stream");
        }
        this.out = out;
    }

    public void log(String message) {
        printMessage(message);
        out.flush();
    }

    public void log(String message, Throwable e) {
        printMessage(message);
        e.printStackTrace(out);
        out.flush();
    }
    
    public void log(String level, String message) {
        out.print(level);
        out.print(": ");
        log(message);
    }

    public void log(String level, String message, Throwable e) {
        out.print(level);
        out.print(": ");
        log(message, e);
    }
    
    private void printMessage(String message) {
        if ( message.charAt(message.length() - 1) == '\n' ) {
            out.print(message);
        }
        else {
            out.println(message);
        }
    }
    
}