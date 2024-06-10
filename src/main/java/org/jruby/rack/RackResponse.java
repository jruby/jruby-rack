/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.util.Map;

/**
 * Represents a Rack response for the Java world.
 *
 * Rack response is an array of exactly three values: [ status, headers, body ]
 *
 * @author nicksieger
 */
public interface RackResponse {

    /**
     * Writes the response (status, headers, and body) to the response environment.
     * @param response the (servlet) response environment
     */
    void respond(final RackResponseEnvironment response) ;

    /**
     * @return the response (HTTP) status
     */
    int getStatus() ;

    /**
     * @return the response headers (string key names)
     */
    Map getHeaders() ;

    /**
     * Note: Normally, this method won't be used at all as we stream the
     * response body from {@link #respond(RackResponseEnvironment)}.
     * @return the response body (as a string)
     */
    String getBody() ;

}
