/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 *
 * @author nicksieger
 */
public interface RackApplicationFactory {
    /** Initialize the factory. */
    void init(RackContext rackContext) throws RackInitializationException;
    /** Create a new, uninitialized application. The resulting object must
     be initialized by calling its {@link RackApplication#init} method. */
    RackApplication newApplication() throws RackInitializationException;
    /** Retrieve an application that is ready to use, possibly creating one
     if necessary. */
    RackApplication getApplication() throws RackInitializationException;
    /** Return the application to the factory, allowing it to be pooled
     and/or cleaned up.*/
    void finishedWithApplication(RackApplication app);
    /** Get the designated error application. The error application is expected
     to be a singleton and should not be returned to the factory. */
    RackApplication getErrorApplication();
    /** Destroy the factory. */
    void destroy();
}
