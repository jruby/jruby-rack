/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public class RackServlet extends HttpServlet {
    private RackDispatcher dispatcher;
    private RackContext rackContext;

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
            rackContext = (RackContext) config.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
            dispatcher = new DefaultRackDispatcher(rackContext);
        }
    }

    @Override
    public void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        dispatcher.process(new ServletRackEnvironment(request, rackContext), new ServletRackResponseEnvironment(response));
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        service((HttpServletRequest) request, (HttpServletResponse) response);
    }
}
