/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

/**
 * @see PoolingRackApplicationFactory#getApplication() 
 * 
 * @author kares
 */
public class AcquireTimeoutException extends RackException {
    
    public AcquireTimeoutException(String message) {
        super(message);
    }

    public AcquireTimeoutException(String message, Throwable cause) {
        super(message, cause);
    }
    
}
