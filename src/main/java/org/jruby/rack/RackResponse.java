/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.util.Map;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author nicksieger
 */
public interface RackResponse {
    /** Return the response status. */
    int getStatus();
    /** Return the response headers. */
    Map getHeaders();
    /** Return the response body */
    String getBody();

    /** Write the status, headers, and body to the response. */
    void respond(HttpServletResponse response);
}
