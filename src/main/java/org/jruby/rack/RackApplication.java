/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.Ruby;

/**
 * Application object that encapsulates the JRuby runtime and the
 * entry point to the web application.
 * @author nicksieger
 */
public interface RackApplication {
    void init() throws RackInitializationException;
    void destroy();

    /**
     * Make a request into the Rack-based Ruby web application.
     *
     * @param env the RackEnvironment
     * @return the RackResponse
     */
    RackResponse call(RackEnvironment env);

    /**
     * Get a reference to the underlying runtime that holds the application
     * and supporting code. Useful for embedding environments that wish to access
     * the application without entering through the web request/response cycle.
     *
     * @return the JRuby runtime
     */
    Ruby getRuntime();
}
