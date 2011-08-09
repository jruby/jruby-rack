/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import org.jruby.rack.RackLogger;

import static java.lang.System.out;

public class StandardOutLogger implements RackLogger {
    public StandardOutLogger(String ignored) {
    }

    public void log(String message) {
        out.println(message.replaceFirst("\n$", ""));
        out.flush();
    }

    public void log(String message, Throwable ex) {
        out.println(message.replaceFirst("\n$", ""));
        ex.printStackTrace(out);
        out.flush();
    }
}
