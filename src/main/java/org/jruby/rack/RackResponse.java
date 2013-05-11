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
 * Rack response is an array of exactly three values: status, headers, and body.
 * 
 * @author nicksieger
 */
public interface RackResponse {
    
    /** 
     * @return the response (HTTP) status
     */
    int getStatus();
    
    /**  
     * @return the response headers
     */
    @SuppressWarnings("rawtypes")
    Map getHeaders();
    
    /** 
     * @return the response body
     */
    String getBody();

    /** 
     * Writes the response (status, headers, and body) to the response environment.
     * @param response the (servlet) response environment
     */
    void respond(RackResponseEnvironment response);
    
}
