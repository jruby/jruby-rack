/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
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
@SuppressWarnings("deprecation")
public class ServletRackEnvironment extends HttpServletRequestWrapper
        implements HttpServletRequest, RackEnvironment {
    private String scriptName;
    private String requestURI;
    private String requestURIWithoutQuery;
    private String pathInfo;
    private RackContext rackContext;

    public ServletRackEnvironment(HttpServletRequest request, RackContext rackContext) {
        super(request);
        this.rackContext = rackContext;
    }

    public RackContext getContext() {
        return rackContext;
    }

    public InputStream getInput() throws IOException {
        return getInputStream();
    }

    /**
     * Define the script name as the context path + the servlet path.
     * @return script name
     */
    public String getScriptName() {
        if (scriptName != null) {
            return scriptName;
        }

        StringBuffer buffer = new StringBuffer("");
        if (getContextPath() != null) {
            buffer.append(getContextPath());
        }
        scriptName =  buffer.toString().equals("/") ? "" : buffer.toString();
        return scriptName;
    }

    /**
     * Rewrite meaning of path info to be either request URI - leading context path or
     * servlet path + path info.
     * @return full path info
     */
    @Override public String getPathInfo() {
        if (pathInfo != null) {
            return pathInfo;
        }
        StringBuffer buffer = new StringBuffer("");
        if (getRequestURIWithoutQuery().length() > 0) {
            if (getScriptName().length() > 0 && getRequestURIWithoutQuery().indexOf(getScriptName()) == 0) {
                buffer.append(getRequestURIWithoutQuery().substring(getScriptName().length()));
            } else {
                buffer.append(getRequestURIWithoutQuery());
            }
        } else {
            buffer.append(getServletPath());
            if (super.getPathInfo() != null) {
                buffer.append(super.getPathInfo());
            }
        }
        pathInfo = buffer.toString();
        return pathInfo;
    }

    /**
     * Rewrite meaning of request URI to include query string.
     * @return
     */
    @Override public String getRequestURI() {
        if (requestURI != null) {
            return requestURI;
        }

        StringBuffer buffer = new StringBuffer("");
        buffer.append(getRequestURIWithoutQuery());
        if (super.getQueryString() != null) {
            buffer.append("?").append(super.getQueryString());
        }
        requestURI = buffer.toString();
        return requestURI;
    }

    /**
     * Return the servlet request's interpretation of request URI.
     * Returns an empty string if the original request returned null.
     * @return the request URI
     */
    public String getRequestURIWithoutQuery() {
        if (requestURIWithoutQuery != null) {
            return requestURIWithoutQuery;
        }
        if (super.getRequestURI() != null) {
            requestURIWithoutQuery = super.getRequestURI();
        } else {
            requestURIWithoutQuery = "";
        }
        return requestURIWithoutQuery;
    }
}
