/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.exceptions.RaiseException;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;

public class RackInitializationException extends Exception {
    public RackInitializationException(RaiseException re) {
        super(exceptionMessage(re), re);
    }

    private static String exceptionMessage(RaiseException re) {
        if (re != null) {
            StringBuilder st = new StringBuilder();
            st.append(re.getException().toString()).append("\n");
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            re.getException().printBacktrace(new PrintStream(b));
            st.append(b.toString());
            return st.toString();
        } else {
            return null;
        }
    }

    public RackInitializationException(String msg, Throwable ex) {
        super(msg, ex);
    }
}
