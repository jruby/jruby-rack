/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import org.jruby.exceptions.RaiseException;

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
