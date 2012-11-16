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
        if (e instanceof RackException) return (RackException) e;
        if (e instanceof RaiseException) {
            return new RackInitializationException((RaiseException) e);
        }
        return new RackInitializationException(e.toString(), e);
    }

}
