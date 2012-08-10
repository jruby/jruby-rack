/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

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
    
}
