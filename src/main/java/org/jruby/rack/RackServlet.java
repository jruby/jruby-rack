/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL/GPL/LGPL tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author nicksieger
 */
public class RackServlet extends HttpServlet {
    public static final String EXCEPTION = "rack.exception";
    private ServletContext servletContext;

    @Override
    public void init(ServletConfig config) {
        this.servletContext = config.getServletContext();
    }
    
    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        process((HttpServletRequest) request, (HttpServletResponse) response);
    }

    public void process(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        final RackApplicationFactory rackFactory = getRackFactory();
        RackApplication app = null;
        try {
            app = rackFactory.getApplication();
            callApplication(app, request, response);
        } catch (Exception re) {
            handleException(re, rackFactory, request, response);
        } finally {
            if (app != null) {
                rackFactory.finishedWithApplication(app);
            }
        }
    }

    private RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory)
            servletContext.getAttribute(RackServletContextListener.FACTORY_KEY);
    }

    private void callApplication(RackApplication app, HttpServletRequest request,
            HttpServletResponse response) {
        RackResult result = app.call(request);
        result.writeStatus(response);
        result.writeHeaders(response);
        result.writeBody(response);
    }

    private void handleException(Exception re, RackApplicationFactory rackFactory,
            HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (response.isCommitted()) {
            servletContext.log("Couldn't handle error: response committed", re);
            return;
        }
        response.reset();

        try {
            RackApplication errorApp = rackFactory.getErrorApplication();
            request.setAttribute(EXCEPTION, re);
            callApplication(errorApp, request, response);
        } catch (Exception e) {
            servletContext.log("Couldn't handle error", e);
            response.sendError(500);
        }
    }
}
