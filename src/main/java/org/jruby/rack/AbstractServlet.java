/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

/**
 *
 * @author nicksieger
 */
@SuppressWarnings("serial")
public abstract class AbstractServlet extends HttpServlet {

    @Override
    public void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {

        RackEnvironment env = new ServletRackEnvironment(request, response, getContext());
        RackResponseEnvironment responseEnv = new ServletRackResponseEnvironment(response);

        getDispatcher().process(env, responseEnv);
    }

    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        service((HttpServletRequest) request, (HttpServletResponse) response);
    }

    @Override
    public void destroy() {
        getDispatcher().destroy();
        super.destroy();
    }

    protected abstract RackDispatcher getDispatcher();

    protected abstract RackContext getContext();

}
