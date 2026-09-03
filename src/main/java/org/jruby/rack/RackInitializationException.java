/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.exceptions.RaiseException;

public class RackInitializationException extends RackException {
    
    public RackInitializationException(String msg) {
        super(msg);
    }
    
    public RackInitializationException(String msg, Throwable e) {
        super(msg, e);
    }
    
    public RackInitializationException(RaiseException e) {
        super(exceptionMessage(e), e);
    }

    static RackException wrap(final Exception e) {
        if (e instanceof RackException rackException) return rackException;
        if (e instanceof RaiseException raiseException) {
            return new RackInitializationException(raiseException);
        }
        return new RackInitializationException(e.toString(), e);
    }

}
