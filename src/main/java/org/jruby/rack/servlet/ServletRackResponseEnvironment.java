/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.RackResponse;
import org.jruby.rack.RackResponseEnvironment;

import java.io.IOException;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 * Servlet response wrapper Rack (response) implementation.
 * 
 * @author nicksieger
 */
public class ServletRackResponseEnvironment extends HttpServletResponseWrapper 
    implements RackResponseEnvironment {
    
    public ServletRackResponseEnvironment(HttpServletResponse response) {
        super(response);
    }
    
    public void defaultRespond(final RackResponse response) throws IOException {
        setStatus(response.getStatus());
        @SuppressWarnings("unchecked")
        final Set<Map.Entry> headers = response.getHeaders().entrySet();
        for ( Iterator<Map.Entry> it = headers.iterator(); it.hasNext(); ) {
            final Map.Entry entry = it.next();
            final String key = entry.getKey().toString();
            final Object value = entry.getValue();
            addHeader(key, value != null ? value.toString() : null);
        }
        getWriter().write(response.getBody());
    }
    
}
