/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;

/**
 * Abstraction away from Java EE servlet request, so Rack applications can be loaded
 * outside of JEE servlet environments.
 * @author nicksieger
 */
public interface RackEnvironment {
    final String EXCEPTION = "jruby.rack.exception";
    final String DYNAMIC_REQS_ONLY = "jruby.rack.dynamic.requests.only";

    // The following methods are specific to the rack environment
    InputStream getInput() throws IOException;
    String getScriptName();
    String getPathInfo();
    /** Request URI should include the query string if available. */
    String getRequestURI();

    // The following methods are usually inherited from the servlet request
    Enumeration getAttributeNames();
    Object getAttribute(String key);
    void setAttribute(String key, Object value);
    Enumeration getHeaderNames();
    String getHeader(String name);
    String getScheme();
    String getContentType();
    int getContentLength();
    String getMethod();
    String getQueryString();
    String getServerName();
    String getRemoteHost();
    String getRemoteAddr();
    String getRemoteUser();
    int getServerPort();
}
