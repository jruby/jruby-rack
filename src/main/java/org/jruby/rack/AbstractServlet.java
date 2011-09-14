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
public abstract class AbstractServlet extends HttpServlet {

    /** Default ctor, used by servlet container */
    public AbstractServlet() {
    }

    @Override
    public void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        getDispatcher().process(new ServletRackEnvironment((HttpServletRequest) request, (HttpServletResponse) response, getContext()),
            new ServletRackResponseEnvironment(response));
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        service((HttpServletRequest) request, (HttpServletResponse) response);
    }

    @Override
    public void destroy() {
        super.destroy();
        getDispatcher().destroy();
    }

    protected abstract RackDispatcher getDispatcher();
    protected abstract RackContext getContext();
}
