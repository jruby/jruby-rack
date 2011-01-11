/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public interface RackResponseEnvironment {
    void defaultRespond(RackResponse response) throws IOException;

    /** Return true if the response has been committed to the socket yet. */
    boolean isCommitted();

    /** Reset the response buffer so we can begin a new response. */
    void reset();

    /** Tell the server to send a simple error page response. */
    void sendError(int code) throws IOException;
}
