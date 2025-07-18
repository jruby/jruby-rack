/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import javax.servlet.ServletOutputStream;
import javax.servlet.WriteListener;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 * Response wrapper passed to filter chain.
 */
public class ResponseCapture extends HttpServletResponseWrapper {

    private static final String STREAM = "stream";
    private static final String WRITER = "writer";

    private static final Collection<Integer> defaultNotHandledStatuses = Collections.singleton(404);

    private Integer status;
    private Object output;

    private boolean handledByDefault;
    private Collection<Integer> notHandledStatuses = defaultNotHandledStatuses;

    /**
     * Wrap a response
     * @param response the response
     */
    public ResponseCapture(HttpServletResponse response) {
        super(response);
    }

    /**
     * @return the status set using one of the set status methods
     * @see #handleStatus(int, boolean)
     */
    public int getStatus() {
        return status != null ? status : 200;
    }

    public boolean isStatusSet() {
        return status != null;
    }

    /**
     * Status code handler customizable by sub-classes.
     *
     * Besides serving as a setter, should return whether the status has been
     * "accepted" (super methods will be called when this is invoked from response
     * API methods such as {@link #setStatus(int)}).
     *
     * @param status the new HTTP status
     * @param error whether the status comes from a {@code sendError}
     * @return the code handler
     * @see #isHandled(HttpServletRequest)
     */
    protected boolean handleStatus(int status, boolean error) {
        this.status = status;
        return isHandled(null);
    }

    @Override
    public void setStatus(int status) {
        // no longer check if there ain't an error before calling super ...
        // if an error has been set previously the caller should deal with it
        if ( handleStatus(status, false) ) {
            super.setStatus(status);
        }
    }

    @Override
    public void setStatus(int status, String message) {
        if ( handleStatus(status, false) ) {
            super.setStatus(status, message);
        }
    }

    @Override
    public void sendError(int status) throws IOException {
        if ( handleStatus(status, true) ) {
            super.sendError(status);
        }
        // after using this method, the response should be considered to be
        // committed and should not be written to ... ever again !
    }

    @Override
    public void sendError(int status, String message) throws IOException {
        if ( handleStatus(status, true) ) {
            super.sendError(status, message);
        }
    }

    @Override
    public void sendRedirect(String path) throws IOException {
        if ( handleStatus(302, false) ) {
            super.sendRedirect(path);
        }
    }

    private boolean headerSet;

    public boolean isHeaderSet() {
        return headerSet;
    }

    @Override
    public void addDateHeader(String name, long date) {
        super.addDateHeader(name, date);
        headerSet = true;
    }

    @Override
    public void addHeader(String name, String value) {
        super.addHeader(name, value);
        headerSet = true;
    }

    @Override
    public void addIntHeader(String name, int value) {
        super.addIntHeader(name, value);
        headerSet = true;
    }

    @Override
    public void setHeader(String name, String value) {
        super.setHeader(name, value);
        headerSet = true;
    }

    @Override
    public void setDateHeader(String name, long date) {
        super.setDateHeader(name, date);
        headerSet = true;
    }

    @Override
    public void setIntHeader(String name, int value) {
        super.setIntHeader(name, value);
        headerSet = true;
    }

    @Override
    public ServletOutputStream getOutputStream() throws IOException {
        if ( output == null ) output = STREAM;

        if ( isHandled(null) ) return super.getOutputStream();
        else { // TODO get rid of this in 1.2.0
            // backwards compatibility with isError() :
            return new ServletOutputStream() {
                @Override
                public boolean isReady() {
                    return true;
                }

                @Override
                public void setWriteListener(WriteListener writeListener) {
                    // swallow listeners, as we're also going to swallow output
                }

                @Override
                public void write(int b) {
                    // swallow output, because we're going to discard it
                }
            };
        }
    }

    @Override
    public PrintWriter getWriter() throws IOException {
        if ( output == null ) output = WRITER;

        // we protect against API limitations as we depend on #getWriter
        // being functional even if getOutputStream has been called ...
        if ( output != WRITER ) {
            String enc = getCharacterEncoding();
            if ( enc == null ) enc = "UTF-8";
            return new PrintWriter(new OutputStreamWriter(getOutputStream(), enc));
        }
        else {
            return super.getWriter();
        }
    }

    @Override
    public void flushBuffer() throws IOException {
        if ( isHandled(null) ) super.flushBuffer();
    }

    public boolean isError() {
        return getStatus() >= 400;
    }

    /**
     * @deprecated no longer to be used from outside
     * @see #isHandled(HttpServletRequest)
     * @return true if handled
     */
    public boolean isHandled() {
        return isHandled(null);
    }

    private boolean handled; // once handled - stays handled

    /**
     * Response is considered to be handled if a status has been set
     * and it is (by default) not a HTTP NOT FOUND (404) status.
     *
     * @param request the request
     * @return true if this response should be considered as handled
     * @see #handleStatus(int, boolean)
     */
    public boolean isHandled(final HttpServletRequest request) {
        if ( handled ) return true; // ... once handled always handled !

        // setting a header should consider the response to be handled
        if ( ! isStatusSet() ) {
            if ( ! isHeaderSet() ) {
                // true by default seems very weird but this is best to cover
                // "more" containers right out of the box ...
                // e.g. Jetty https://github.com/jruby/jruby-rack/issues/175
                return handled = isHandledByDefault();
            }

            // consider HTTP OPTIONS with "Allow" header unhandled :
            if ( request != null && "OPTIONS".equals( request.getMethod() ) ) {
                final Collection<String> headerNames = getHeaderNames();
                if ( headerNames == null || headerNames.isEmpty() ) {
                    // not to happen but there's all kind of beasts out there
                    return false;
                }
                // Tomcat's DefaultServlet sets 'Allow' header but Jetty also sets the 'Date' header with its servlet
                // ... if any other headers occur beside 'Allow' and 'Date' we consider this request handled
                for ( final String headerName : headerNames ) {
                    if ( ! "Allow".equals( headerName ) && ! "Date".equals( headerName ) ) {
                        return handled = true;
                    }
                }
                return false; // OPTIONS with only 'Allow' (and/or 'Date') header set - unhandled
            }
            return handled = true;
        }

        if ( notHandledStatuses.contains( getStatus() ) ) return false;
        return handled = true;
    }

    public Collection<Integer> getNotHandledStatuses() {
        return this.notHandledStatuses;
    }

    @SuppressWarnings("unchecked")
    public void setNotHandledStatuses(final Collection<Integer> notHandledStatuses) {
        this.notHandledStatuses =
            notHandledStatuses == null ? Collections.EMPTY_SET : notHandledStatuses;
    }

    boolean isHandledByDefault() {
        return handledByDefault;
    }

    public void setHandledByDefault(boolean handledByDefault) {
        this.handledByDefault = handledByDefault;
    }

    /**
     * @return true if {@link #getOutputStream()} (or {@link #getWriter()}) has
     * been accessed
     */
    public boolean isOutputAccessed() {
        return output != null;
    }
}
