/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;

/**
 *
 * @author nicksieger
 */
public class DefaultServletDispatcher implements ServletDispatcher {
    private RackContext context;

    public DefaultServletDispatcher(RackContext servletContext) {
        this.context = servletContext;
    }

    public void process(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        final RackApplicationFactory rackFactory = context.getRackFactory();
        RackApplication app = null;
        try {
            app = rackFactory.getApplication();
            app.call(new ServletRackEnvironment(request)).respond(new ServletRackResponseEnvironment(response));
        } catch (Exception re) {
            handleException(re, rackFactory, request, response);
        } finally {
            if (app != null) {
                rackFactory.finishedWithApplication(app);
            }
        }
    }

    private void handleException(Exception re, RackApplicationFactory rackFactory,
            HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (response.isCommitted()) {
            context.log("Error: Couldn't handle error: response committed", re);
            return;
        }
        response.reset();
        context.log("Application Error", re);

        try {
            RackApplication errorApp = rackFactory.getErrorApplication();
            request.setAttribute(RackEnvironment.EXCEPTION, re);
            errorApp.call(new ServletRackEnvironment(request)).respond(new ServletRackResponseEnvironment(response));
        } catch (Exception e) {
            context.log("Error: Couldn't handle error", e);
            response.sendError(500);
        }
    }
}
