/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

/**
 * Rack response environment interface that is likely to be only implemented 
 * as a servlet response.
 * 
 * @see javax.servlet.ServletResponse
 * @see RackResponse
 * 
 * @author nicksieger
 */
public interface RackResponseEnvironment {
    
    /**
     * @see RackResponse#respond(RackResponseEnvironment)
     * @param response
     * @throws IOException 
     */
    void defaultRespond(RackResponse response) throws IOException;

    /**
     * @return whether the underlying (servlet) response has been committed.
     */
    boolean isCommitted();

    /**
     * Reset the response buffer so we can begin a new response.
     */
    void reset();

    /**
     * Tell the server to send a simple error page response (based on the 
     * status code).
     * @param code the (HTTP) status code
     * @throws IOException 
     */
    void sendError(int code) throws IOException;
    
}
