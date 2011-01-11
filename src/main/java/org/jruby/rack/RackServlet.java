/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.servlet.ServletRackContext;
import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

/**
 *
 * @author nicksieger
 */
public class RackServlet extends HttpServlet {
    private RackDispatcher dispatcher;

    /** Default ctor, used by servlet container */
    public RackServlet() {
    }

    /** dependency injection ctor, used by unit tests */
    public RackServlet(RackDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Override
    public void init(ServletConfig config) {
        if (dispatcher == null) {
            dispatcher = new DefaultRackDispatcher(new ServletRackContext(config.getServletContext()));
        }
    }

    @Override
    public void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        dispatcher.process(new ServletRackEnvironment(request), new ServletRackResponseEnvironment(response));
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        service((HttpServletRequest) request, (HttpServletResponse) response);
    }
}
