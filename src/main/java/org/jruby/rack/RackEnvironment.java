/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.ext.Input;
import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;

/**
 * Represent a Rack environment (that will most likely by wrapping a
 * {@link javax.servlet.http.HttpServletRequest}).
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
    final String EXCEPTION = "jruby.rack.exception";
    final String DYNAMIC_REQS_ONLY = "jruby.rack.dynamic.requests.only";

    /**
     * @return the associated {@link RackContext} for this environment
     */
    public RackContext getContext();

    // The following methods are specific to the rack environment

    /**
     * @see javax.servlet.ServletRequest#getInputStream()
     * @return the input as a stream
     * @throws IOException
     */
    public InputStream getInput() throws IOException;

    /**
     * For servlet-based environment implementations the script name might be
     * constructed as the the (servlet) context path + the servlet path.
     * @return the script name ("CGI" style)
     */
    public String getScriptName();

    // The following methods are usually inherited from the servlet request

    /**
     * @see javax.servlet.http.HttpServletRequest#getPathInfo()
     */
    public String getPathInfo();

    /**
     * Request URI should include the query string if available.
     * @see javax.servlet.http.HttpServletRequest#getRequestURI()
     */
    public String getRequestURI();

    /**
     * @see javax.servlet.http.HttpServletRequest#getAttributeNames()
     */
    public Enumeration<String> getAttributeNames();

    /**
     * @see javax.servlet.http.HttpServletRequest#getAttribute(String)
     */
    public Object getAttribute(String key);

    /**
     * @see javax.servlet.http.HttpServletRequest#setAttribute(String, Object)
     */
    public void setAttribute(String key, Object value);

    /**
     * @see javax.servlet.http.HttpServletRequest#getHeaderNames()
     */
    public Enumeration<String> getHeaderNames();

    /**
     * @see javax.servlet.http.HttpServletRequest#getHeader(String)
     */
    public String getHeader(String name);

    /**
     * @see javax.servlet.http.HttpServletRequest#getScheme()
     */
    public String getScheme();

    /**
     * @see javax.servlet.http.HttpServletRequest#getContentType()
     */
    public String getContentType();

    /**
     * @see javax.servlet.http.HttpServletRequest#getContentLength()
     */
    public int getContentLength();

    /**
     * @see javax.servlet.http.HttpServletRequest#getMethod()
     */
    public String getMethod();

    /**
     * @see javax.servlet.http.HttpServletRequest#getQueryString()
     */
    public String getQueryString();

    /**
     * @see javax.servlet.http.HttpServletRequest#getServerName()
     */
    public String getServerName();

    /**
     * @see javax.servlet.http.HttpServletRequest#getServerPort()
     */
    public int getServerPort();

    /**
     * @see javax.servlet.ServletRequest#getRemoteHost()
     */
    public String getRemoteHost();

    /**
     * @see javax.servlet.ServletRequest#getRemoteAddr()
     */
    public String getRemoteAddr();

    /**
     * @see javax.servlet.http.HttpServletRequest#getRemoteUser()
     */
    public String getRemoteUser();

    /**
     * {@link RackEnvironment} extension to obtain a rack.input IO.
     *
     * NOTE: This interface will most likely get moved onto the (parent)
     * environment interface directly once the deprecated way of maintaining
     * backwards compatibility (using jruby/rack/environment.rb) is removed.
     *
     * @deprecated Was an internal interface and is no longer used.
     * @author kares
     */
    @Deprecated
    interface ToIO {

        // TODO move to RackEnvironment once jruby/rack/environment.rb removed

        /**
         * Convert this environment into a "rack.input" IO.
         * Replaces the <code>to_io</code> monkey-patch ...
         * @return rack.input
         */
        public Input toIO();

        /**
         * Set the rack.input, this is an optional operation and implementers
         * might ignore this call silently if they're capable of constructing
         * the rack.input themselves.
         * @param io the rack.input instance
         */
        void setIO(Input io) ;

    }

    /**
     * Convert this environment into a "rack.input" IO.
     * Replaces the <code>to_io</code> monkey-patch ...
     * @return rack.input
     */
    //public Input toIO() ;

}
