/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.logging;

import java.io.PrintStream;

public class StandardOutLogger extends OutputStreamLogger {

    public StandardOutLogger() {
        super(System.out);
    }

    public StandardOutLogger(PrintStream out) {
        super(out);
    }

}
