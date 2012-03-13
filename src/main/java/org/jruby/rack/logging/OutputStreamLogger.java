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
        out.println(message.replaceFirst("\n$", ""));
        out.flush();
    }

    public void log(String message, Throwable e) {
        out.println(message.replaceFirst("\n$", ""));
        e.printStackTrace(out);
        out.flush();
    }
    
}