/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

/**
 *
 * @author nicksieger
 */
public abstract class AbstractServlet extends HttpServlet {

    @Override
    public void service(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        
        HttpServletRequest httpRequest   = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        RackEnvironment env                 = new ServletRackEnvironment(httpRequest, httpResponse, getContext());
        RackResponseEnvironment responseEnv = new ServletRackResponseEnvironment(httpResponse);
        
        getDispatcher().process(env, responseEnv);
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
