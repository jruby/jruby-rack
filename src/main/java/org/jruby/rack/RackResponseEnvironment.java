/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;

/**
 * Rack response environment (the response environment that is used to actually
 * handle and return the Rack response) interface.
 * It is likely to be (only) implemented as a HTTP servlet response.
 *
 * @see javax.servlet.ServletResponse
 * @see javax.servlet.http.HttpServletResponse
 * @see RackResponse
 *
 * @author nicksieger
 */
public interface RackResponseEnvironment {

    /**
     * @return whether the underlying response has been committed.
     * @see javax.servlet.ServletResponse#isCommitted()
     */
    boolean isCommitted();

    /**
     * Reset the response (buffer) so we can begin a new response.
     * @see javax.servlet.ServletResponse#reset()
     */
    void reset();

    /**
     * @see javax.servlet.ServletResponse#setContentType(String)
     * @param type the content type
     */
    void setContentType(String type) ;

    /**
     * @see javax.servlet.ServletResponse#setContentLength(int)
     * @param length the content length
     */
    void setContentLength(int length) ;

    /**
     * @see javax.servlet.ServletResponse#setCharacterEncoding(String)
     * @param charset the charset
     */
    void setCharacterEncoding(String charset) ;

    /**
     * Sets a (HTTP) header.
     * @param name the header name
     * @param value the header value as a String
     */
    void setHeader(String name, String value) ;
    /**
     * Adds a (HTTP) header.
     * @param name the header name
     * @param value the header value as a String
     */
    void addHeader(String name, String value) ;

    /**
     * Sets a (HTTP) header.
     * @param name the header name
     * @param date the header value as a long date
     */
    void setDateHeader(String name, long date) ;
    /**
     * Adds a (HTTP) header.
     * @param name the header name
     * @param date the header value as a long date
     */
    void addDateHeader(String name, long date) ;

    /**
     * Sets a (HTTP) header.
     * @param name the header name
     * @param value the header value as an int
     */
    void setIntHeader(String name, int value) ;
    /**
     * Adds a (HTTP) header.
     * @param name the header name
     * @param value the header value as an int
     */
    void addIntHeader(String name, int value) ;

    /**
     * Sets the response (HTTP) status.
     * @param code the (HTTP) status code
     */
    void setStatus(int code) ;

    /**
     * Send a simple error page response (based on the status code).
     * @param code the (HTTP) status code
     * @throws IOException if there's an IO exception
     */
    void sendError(int code) throws IOException ;

    /**
     * @see javax.servlet.ServletResponse#getOutputStream()
     * @return the output stream
     * @throws IOException if there's an IO exception
     */
    OutputStream getOutputStream() throws IOException ;

    /**
     * @see javax.servlet.ServletResponse#getWriter()
     * @return the writer
     * @throws IOException if there's an IO exception
     */
    PrintWriter getWriter() throws IOException ;

}
