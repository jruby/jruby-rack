/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.logging;

import static java.lang.System.out;

import org.jruby.rack.RackLogger;

public class StandardOutLogger implements RackLogger {
    public void log(String message) {
        out.println(message);
        out.flush();
    }

    public void log(String message, Throwable ex) {
        out.println(message);
        ex.printStackTrace(out);
        out.flush();
    }
}
