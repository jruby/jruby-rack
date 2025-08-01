/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import javax.servlet.ServletInputStream;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;

import org.jruby.rack.RackConfig;

/**
 * Request wrapper passed to filter chain.
 */
@SuppressWarnings("rawtypes")
public class RequestCapture extends HttpServletRequestWrapper {

    private Map<String,String[]> requestParams;
    private RewindableInputStream inputStream;

    /**
     * Wrap a request
     * @param request the request
     */
    public RequestCapture(HttpServletRequest request) {
        super(request);
    }
    
    /**
     * @deprecated use {@link #RequestCapture(HttpServletRequest)}
     * @param request the request
     * @param config will be ignored
     */
    @Deprecated
    public RequestCapture(HttpServletRequest request, RackConfig config) {
        this(request);
    }

    @Override 
    public BufferedReader getReader() throws IOException {
        String enc = getCharacterEncoding();
        if (enc == null) {
            enc = "UTF-8";
        }
        return new BufferedReader(new InputStreamReader(getInputStream(), enc));
    }
    
    @Override 
    public ServletInputStream getInputStream() throws IOException {
        if (inputStream == null) {
            inputStream = new RewindableInputStream(super.getInputStream());
        }
        return inputStream;
    }

    @Override
    public String getParameter(String name) {
        if ( requestParametersParsed() ) {
            String[] values = requestParams.get(name);
            if (values != null) {
                return values[0];
            }
            return null;
        } else {
            return super.getParameter(name);
        }
    }

    @Override
    public Map getParameterMap() {
        if ( requestParametersParsed() ) {
            return requestParams;
        } else {
            return super.getParameterMap();
        }
    }

    @Override
    public Enumeration getParameterNames() {
        if ( requestParametersParsed() ) {
            return new Enumeration() {
                Iterator keys = requestParams.keySet().iterator();
                public boolean hasMoreElements() {
                    return keys.hasNext();
                }

                public Object nextElement() {
                    return keys.next();
                }
            };
        } else {
            return super.getParameterNames();
        }
    }

    @Override
    public String[] getParameterValues(String name) {
        if ( requestParametersParsed() ) {
            return requestParams.get(name);
        } else {
            return super.getParameterValues(name);
        }
    }

    private boolean parseRequestParams() {
        if ( this.requestParams != null ) return true;
        if ( ! "application/x-www-form-urlencoded".equals(super.getContentType()) ) {
            return false;
        }
        // Need to re-parse form params from the request
        // All this because you can't mix use of request#getParameter
        // and request#getInputStream in the Servlet API.
        String line = "";
        try {
            line = getReader().readLine();
        } 
        catch (IOException e) { /* ignored */ }
        if (line == null) return false;
        
        final Map<String,String[]> params = new HashMap<>();
        final String[] pairs = line.split("\\&");
        for (String pair : pairs) {
            String[] fields = pair.split("=", 2);
            String key = URLDecoder.decode(fields[0], StandardCharsets.UTF_8);
            String value = null;
            if (fields.length == 2) {
                value = URLDecoder.decode(fields[1], StandardCharsets.UTF_8);
            }
            if (value != null) {
                String[] newValues;
                if (params.containsKey(key)) {
                    String[] values = params.get(key);
                    newValues = new String[values.length + 1];
                    System.arraycopy(values, 0, newValues, 0, values.length);
                    newValues[values.length] = value;
                } else {
                    newValues = new String[1];
                    newValues[0] = value;
                }
                params.put(key, newValues);
            }
        }
        
        this.requestParams = params;
        return true;
    }

    private boolean requestParametersParsed() {
        return parseRequestParams() && requestParams.size() >= super.getParameterMap().size();
    }
    
    
    public void reset() throws IOException {
        if ( inputStream != null ) inputStream.rewind();
    }
    
    /**
     * @return true if {@link #getInputStream()} (or {@link #getReader()}) has 
     * been accessed
     */
    public boolean isInputAccessed() {
        return inputStream != null;
    }
    
}
