/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.IOException;

import javax.servlet.ServletInputStream;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInput;

/**
 * Rack environment (default) implementation based on {@link HttpServletRequest}..
 * 
 * @see RackEnvironment
 * @see HttpServletRequest
 * @see HttpServletRequestWrapper
 * 
 * @author nicksieger
 */
@SuppressWarnings("deprecation")
public class ServletRackEnvironment extends HttpServletRequestWrapper
    implements RackEnvironment, RackEnvironment.ToIO {
    
    private String scriptName;
    private String requestURI;
    private String requestURIWithoutQuery;
    private String pathInfo;
    
    private final RackContext context;
    private final HttpServletResponse response;
    
    /**
     * Creates an environment instance for the given request, response and context.
     * @param request
     * @param response
     * @param context 
     */
    public ServletRackEnvironment(HttpServletRequest request, HttpServletResponse response, RackContext context) {
        super(request);
        this.response = response;
        this.context = context;
    }

    /**
     * @see RackEnvironment#getContext() 
     */
    public RackContext getContext() {
        return context;
    }
    
    /**
     * The underlying HttpServletResponse
     * @return the response
     */
    public HttpServletResponse getResponse() {
    	return response;
    }
    
    /**
     * @see RackEnvironment#getInput()
     */
    public ServletInputStream getInput() throws IOException {
        return getInputStream();
    }
    
    /**
     * Define the script name as the context path + the servlet path.
     * @return script name
     * @see RackEnvironment#getScriptName()
     */
    public String getScriptName() {
        if (scriptName != null) {
            return scriptName;
        }

        String contextPath = getContextPath();
        if (contextPath == null) contextPath = "";
        return scriptName = contextPath.equals("/") ? "" : contextPath;
    }

    /**
     * Rewrite meaning of path info to be either request URI - leading context path or
     * servlet path + path info.
     * @return full path info
     * @see RackEnvironment#getPathInfo()
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
        return pathInfo = buffer.toString();
    }

    /**
     * Rewrite meaning of request URI to include query string.
     * @return URI
     * @see RackEnvironment#getRequestURI()
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
        return requestURI = buffer.toString();
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

    private RackInput io;
    
    public RackInput toIO() {
        return io;
    }
    
    public void setIO(RackInput io) {
        this.io = io;
    }
    
}
