/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
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

import org.jruby.rack.servlet.DefaultServletDispatcher;
import org.jruby.rack.servlet.ServletDispatcher;
import org.jruby.rack.servlet.ServletRackContext;

/**
 *
 * @author nicksieger
 */
public class RackServlet extends HttpServlet {
    private ServletDispatcher dispatcher;

    /** Default ctor, used by servlet container */
    public RackServlet() {
    }

    /** dependency injection ctor, used by unit tests */
    public RackServlet(ServletDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Override
    public void init(ServletConfig config) {
        this.dispatcher = new DefaultServletDispatcher(new ServletRackContext(config.getServletContext()));
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        dispatcher.process((HttpServletRequest) request, (HttpServletResponse) response);
    }

}
