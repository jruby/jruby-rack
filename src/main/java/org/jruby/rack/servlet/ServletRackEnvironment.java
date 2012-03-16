/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.InputStream;

/**
 * Implementation of RackEnvironment for the servlet environment.
 * @author nicksieger
 */
@SuppressWarnings("deprecation")
public class ServletRackEnvironment extends HttpServletRequestWrapper
    implements RackEnvironment {
    
    private String scriptName;
    private String requestURI;
    private String requestURIWithoutQuery;
    private String pathInfo;
    private final RackContext rackContext;
    private final HttpServletResponse response;

    public ServletRackEnvironment(HttpServletRequest request, HttpServletResponse response, RackContext rackContext) {
        super(request);
        this.response = response;
        this.rackContext = rackContext;
    }

    public RackContext getContext() {
        return rackContext;
    }

    public InputStream getInput() throws IOException {
        return getInputStream();
    }
    
    /**
     * The underlying HttpServletResponse
     * @return
     */
    public HttpServletResponse getResponse() {
    	return response;
    }

    /**
     * Define the script name as the context path + the servlet path.
     * @return script name
     */
    public String getScriptName() {
        if (scriptName != null) {
            return scriptName;
        }

        String contextPath = getContextPath();
        if (contextPath == null) contextPath = "";
        scriptName = contextPath.equals("/") ? "" : contextPath;
        return scriptName;
    }

    /**
     * Rewrite meaning of path info to be either request URI - leading context path or
     * servlet path + path info.
     * @return full path info
     */
    @Override 
    public String getPathInfo() {
        if (pathInfo != null) {
            return pathInfo;
        }
        
        StringBuilder buffer = new StringBuilder();
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
    @Override 
    public String getRequestURI() {
        if (requestURI != null) {
            return requestURI;
        }

        StringBuilder buffer = new StringBuilder();
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
        requestURIWithoutQuery = super.getRequestURI();
        if (requestURIWithoutQuery == null) {
            requestURIWithoutQuery = "";
        }
        return requestURIWithoutQuery;
    }
    
}
