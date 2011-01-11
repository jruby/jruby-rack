/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public class DefaultRackDispatcher implements RackDispatcher {
    private RackContext context;

    public DefaultRackDispatcher(RackContext servletContext) {
        this.context = servletContext;
    }

    public void process(RackEnvironment request, RackResponseEnvironment response)
        throws IOException {
        final RackApplicationFactory rackFactory = context.getRackFactory();
        RackApplication app = null;
        try {
            app = rackFactory.getApplication();
            app.call(request).respond(response);
        } catch (Exception re) {
            handleException(re, rackFactory, request, response);
        } finally {
            if (app != null) {
                rackFactory.finishedWithApplication(app);
            }
        }
    }

    private void handleException(Exception re, RackApplicationFactory rackFactory,
            RackEnvironment request, RackResponseEnvironment response)
            throws IOException {
        if (response.isCommitted()) {
            context.log("Error: Couldn't handle error: response committed", re);
            return;
        }
        response.reset();
        context.log("Application Error", re);

        try {
            RackApplication errorApp = rackFactory.getErrorApplication();
            request.setAttribute(RackEnvironment.EXCEPTION, re);
            errorApp.call(request).respond(response);
        } catch (Exception e) {
            context.log("Error: Couldn't handle error", e);
            response.sendError(500);
        }
    }
}
