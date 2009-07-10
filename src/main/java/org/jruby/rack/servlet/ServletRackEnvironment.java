/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.*;
import java.io.IOException;
import java.io.InputStream;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;

/**
 * Implementation of RackEnvironment for the servlet environment.
 * @author nicksieger
 */
public class ServletRackEnvironment extends HttpServletRequestWrapper
        implements HttpServletRequest, RackEnvironment {
    public ServletRackEnvironment(HttpServletRequest request) {
        super(request);
    }

    public InputStream getInput() throws IOException {
        return getInputStream();
    }

    /**
     * Define the script name as the context path + the servlet path.
     * @return script name
     */
    public String getScriptName() {
        StringBuffer scriptName = new StringBuffer("");
        if (getContextPath() != null) {
            scriptName.append(getContextPath());
        }
        scriptName.append(getServletPath());
        return scriptName.toString().equals("/") ? "" : scriptName.toString();
    }

    /**
     * Rewrite meaning of path info to be servlet path + path info.
     * @return full path info
     */
    @Override public String getPathInfo() {
        StringBuffer pathInfo = new StringBuffer("");
        if (getServletPath() != null) {
            pathInfo.append(getServletPath());
        }
        if (super.getPathInfo() != null) {
            pathInfo.append(super.getPathInfo());
        }
        return pathInfo.toString();
    }

    /**
     * Rewrite meaning of request URI to include query string.
     * @return
     */
    @Override public String getRequestURI() {
        StringBuffer requestURI = new StringBuffer("");
        if (super.getRequestURI() != null) {
            requestURI.append(super.getRequestURI());
        }
        if (super.getQueryString() != null) {
            requestURI.append("?").append(super.getQueryString());
        }
        return requestURI.toString();
    }
}
