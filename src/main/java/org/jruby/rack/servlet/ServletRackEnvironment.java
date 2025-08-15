/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.servlet;

import java.io.IOException;

import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.ext.Input;

/**
 * Rack environment (default) implementation based on {@link HttpServletRequest}..
 *
 * @see RackEnvironment
 * @see HttpServletRequest
 * @see HttpServletRequestWrapper
 *
 * @author nicksieger
 */
public class ServletRackEnvironment extends HttpServletRequestWrapper
    implements RackEnvironment {

    private String scriptName;
    private String requestURI;
    private String requestURIWithoutQuery;
    private String pathInfo;

    private final RackContext context;
    private final HttpServletResponse response;

    /**
     * Creates an environment instance for the given request, response and context.
     * @param request the request
     * @param response the response
     * @param context the context
     */
    public ServletRackEnvironment(HttpServletRequest request, HttpServletResponse response, RackContext context) {
        super(request);
        if ( response == null ) throw new IllegalArgumentException("null response");
        this.response = response;
        if ( context == null ) throw new IllegalArgumentException("null context");
        this.context = context;
    }

    /**
     * @see RackEnvironment#getContext()
     */
    @Override
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
    @Override
    public ServletInputStream getInput() throws IOException {
        return getInputStream();
    }

    /**
     * Define the script name as the context path + the servlet path.
     * @return script name
     * @see RackEnvironment#getScriptName()
     */
    @Override
    public String getScriptName() {
        if ( scriptName != null ) return scriptName;

        String contextPath = getContextPath();
        if ( contextPath == null ) contextPath = "";
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
        if ( pathInfo != null ) return pathInfo;

        final StringBuilder buffer = new StringBuilder(32);
        final String onlyURI = getRequestURIWithoutQuery();
        if (!onlyURI.isEmpty()) {
            final String script = getScriptName();
            if ( script != null && !script.isEmpty()
                && onlyURI.indexOf(script) == 0 ) {
                buffer.append( onlyURI.substring(script.length()) );
            } else {
                buffer.append( onlyURI );
            }
        } else {
            buffer.append( getServletPath() );
            if ( super.getPathInfo() != null ) {
                buffer.append( super.getPathInfo() );
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
        if ( requestURI != null ) return requestURI;

        final StringBuilder buffer = new StringBuilder(32);
        buffer.append( getRequestURIWithoutQuery() );
        if ( super.getQueryString() != null ) {
            buffer.append('?').append( super.getQueryString() );
        }
        return requestURI = buffer.toString();
    }

    /**
     * Return the servlet request's interpretation of request URI.
     * Returns an empty string if the original request returned null.
     * @return the request URI
     */
    public String getRequestURIWithoutQuery() {
        if ( requestURIWithoutQuery != null ) return requestURIWithoutQuery;

        final String defaultURI = super.getRequestURI();
        return requestURIWithoutQuery = defaultURI == null ? "" : defaultURI;
    }

    private Input io;

    @Deprecated public Input toIO() { return io; }

    @Deprecated public void setIO(Input io) { this.io = io; }

}
