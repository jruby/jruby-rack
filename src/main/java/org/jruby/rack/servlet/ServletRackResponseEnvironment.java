/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.*;
import java.io.IOException;
import java.util.Iterator;
import java.util.Map.Entry;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

/**
 *
 * @author nicksieger
 */
public class ServletRackResponseEnvironment extends HttpServletResponseWrapper 
        implements RackResponseEnvironment {
    public ServletRackResponseEnvironment(HttpServletResponse response) {
        super(response);
    }

    public void defaultRespond(RackResponse response) throws IOException {
        setStatus(response.getStatus());
        for (Iterator it = response.getHeaders().entrySet().iterator(); it.hasNext();) {
            Entry entry = (Entry) it.next();
            addHeader(entry.getKey().toString(), entry.getValue().toString());
        }
        getWriter().write(response.getBody());
    }
}
