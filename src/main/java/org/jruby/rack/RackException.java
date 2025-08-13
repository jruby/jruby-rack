/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;

import org.jruby.exceptions.RaiseException;

/**
 * A base class for JRuby-Rack exceptions.
 * 
 * @author kares
 */
public class RackException extends RuntimeException {

    public RackException(String message) {
        super(message);
    }

    public RackException(Throwable cause) {
        super(cause);
    }

    public RackException(String message, Throwable cause) {
        super(message, cause);
    }
    
    /**
     * Returns the root cause exception.
     *
     * @return	the (root) <code>Throwable</code> that caused this exception
     */
    public Throwable getRootCause() {
        Throwable cause = getCause();
        if ( cause != null ) {
            while ( cause.getCause() != null ) {
                cause = cause.getCause();
            }
        }
        return cause;
    }
    
    static RackException wrap(final Exception e) {
        if (e instanceof RackException) return (RackException) e;
        return new RackException(e);
    }

    static String exceptionMessage(final RaiseException e) {
        if (e != null) {
            StringBuilder st = new StringBuilder();
            st.append(e.getException().toString()).append('\n');
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            e.getException().printBacktrace(new PrintStream(b));
            st.append(b);
            return st.toString();
        }
        return null;
    }
    
}
