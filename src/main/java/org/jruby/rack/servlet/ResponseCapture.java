/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.util.Collection;
import java.util.Collections;

import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 * Response wrapper passed to filter chain.
 */
public class ResponseCapture extends HttpServletResponseWrapper {
    
    private static final String STREAM = "stream";
    private static final String WRITER = "writer";
    
    private static Collection<Integer> defaultNotHandledStatuses = Collections.singleton(404);
    
    private int status = 404;
    private Object output;
    
    private Collection<Integer> notHandledStatuses = defaultNotHandledStatuses;
    
    /**
     * Wrap a response
     * @param response 
     */
    public ResponseCapture(HttpServletResponse response) {
        super(response);
    }
    
    /**
     * @return the status set using one of the set status methods
     * @see #handleStatus(int, boolean) 
     */
    public int getStatus() {
        return this.status;
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
     * @see #isHandled()
     */
    protected boolean handleStatus(int status, boolean error) {
        this.status = status;
        return isHandled();
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

    @Override 
    public ServletOutputStream getOutputStream() throws IOException {
        if ( output == null ) output = STREAM;
        
        if ( isHandled() ) {
            return super.getOutputStream();
        }
        else {
            // backwards compatibility with isError() then :
            return new ServletOutputStream() {
                @Override 
                public void write(int b) throws IOException {
                    // swallow output, because we're going to discard it
                }
            };
        }
    }

    @Override
    public PrintWriter getWriter() throws IOException {
        if ( output == null ) output = WRITER;
        
        if ( isHandled() ) {
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
        else {
            // backwards compatibility with isError() then :
            return new PrintWriter(new OutputStream() {
                @Override 
                public void write(int b) throws IOException {
                    // swallow output, because we're going to discard it
                }
            });
        }
    }
    
    @Override
    public void flushBuffer() throws IOException {
        if ( isHandled() ) super.flushBuffer();
    }
    
    public boolean isError() {
        return getStatus() >= 400;
    }

    /**
     * Response is considered to be handled if a status has been set 
     * and it is (by default) not a HTTP NOT FOUND (404) status.
     * 
     * @return true if this response should be considered as handled
     * @see #handleStatus(int, boolean) 
     */
    public boolean isHandled() {
        return ! notHandledStatuses.contains( getStatus() );
    }

    public Collection<Integer> getNotHandledStatuses() {
        return this.notHandledStatuses;
    }
    
    @SuppressWarnings("unchecked")
    public void setNotHandledStatuses(final Collection<Integer> notHandledStatuses) {
        this.notHandledStatuses =
            notHandledStatuses == null ? Collections.EMPTY_SET : notHandledStatuses;
    }
    
    /**
     * @return true if {@link #getOutputStream()} (or {@link #getWriter()}) has 
     * been accessed
     */
    public boolean isOutputAccessed() {
        return output != null;
    }
    
}
