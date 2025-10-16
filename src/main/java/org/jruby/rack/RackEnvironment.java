/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;

/**
 * Represent a Rack environment (that will most likely by wrapping a
 * {@link jakarta.servlet.http.HttpServletRequest}).
 * Allows Rack applications to be loaded outside of JEE servlet environments.
 *
 * @see org.jruby.rack.servlet.ServletRackEnvironment
 *
 * @author nicksieger
 */
public interface RackEnvironment {

    /**
     * Environment key that retrieves the exception the {@link RackApplication}
     * failed with. Useful when dispatching call to an {@link ErrorApplication}.
     */
    String EXCEPTION = "jruby.rack.exception";
    String DYNAMIC_REQS_ONLY = "jruby.rack.dynamic.requests.only";

    /**
     * @return the associated {@link RackContext} for this environment
     */
    RackContext getContext();

    // The following methods are specific to the rack environment

    /**
     * @see jakarta.servlet.ServletRequest#getInputStream()
     * @return the input as a stream
     * @throws IOException if there's an IO exception
     */
    InputStream getInput() throws IOException;

    /**
     * For servlet-based environment implementations the script name might be
     * constructed as the the (servlet) context path + the servlet path.
     * @return the script name ("CGI" style)
     */
    String getScriptName();

    // The following methods are usually inherited from the servlet request

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getPathInfo()
     * @return the request path info
     */
    String getPathInfo();

    /**
     * Request URI should include the query string if available.
     * @see jakarta.servlet.http.HttpServletRequest#getRequestURI()
     * @return the request URI
     */
    String getRequestURI();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getAttributeNames()
     * @return an enumeration of all attribute names
     */
    Enumeration<String> getAttributeNames();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getAttribute(String)
     * @param key the attribute key
     * @return the attribute value
     */
    Object getAttribute(String key);

    /**
     * @see jakarta.servlet.http.HttpServletRequest#setAttribute(String, Object)
     * @param key the key
     * @param value the value
     */
    void setAttribute(String key, Object value);

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getHeaderNames()
     * @return an enumeration of all header names
     */
    Enumeration<String> getHeaderNames();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getHeader(String)
     * @param name the header name
     * @return the header value
     */
    String getHeader(String name);

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getScheme()
     * @return the request scheme
     */
    String getScheme();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getContentType()
     * @return the content type
     */
    String getContentType();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getContentLength()
     * @return the content length
     */
    int getContentLength();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getMethod()
     * @return the request method
     */
    String getMethod();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getQueryString()
     * @return the query string
     */
    String getQueryString();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getServerName()
     * @return the server name
     */
    String getServerName();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getServerPort()
     * @return the server port
     */
    int getServerPort();

    /**
     * @see jakarta.servlet.ServletRequest#getRemoteHost()
     * @return the remote host
     */
    String getRemoteHost();

    /**
     * @see jakarta.servlet.ServletRequest#getRemoteAddr()
     * @return the remote address
     */
    String getRemoteAddr();

    /**
     * @see jakarta.servlet.http.HttpServletRequest#getRemoteUser()
     * @return the remote user
     */
    String getRemoteUser();
}
