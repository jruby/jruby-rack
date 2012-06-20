/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

import org.jruby.rack.servlet.ServletRackContext;

/**
 * Dispatcher suited for use in a servlet container
 * @author nick
 *
 */
public class DefaultRackDispatcher extends AbstractRackDispatcher {

    public DefaultRackDispatcher(RackContext rackContext) {
        super(rackContext);
    }

    @Override
    protected RackApplication getApplication() throws RackInitializationException {
        return getRackFactory().getApplication();
    }

    @Override
    protected void afterException(RackEnvironment request, Exception re,
            RackResponseEnvironment response) throws IOException {
        try {
            RackApplication errorApp = getRackFactory().getErrorApplication();
            request.setAttribute(RackEnvironment.EXCEPTION, re);
            errorApp.call(request).respond(response);
        } catch (Exception e) {
            context.log(RackLogger.ERROR, "couldn't handle error", e);
            response.sendError(500);
        }
    }

    @Override
    protected void afterProcess(RackApplication app) {
        getRackFactory().finishedWithApplication(app);
    }
    
    @Override
    public void destroy() {
        getRackFactory().destroy();
    }

    protected RackApplicationFactory getRackFactory() {
        if (context instanceof ServletRackContext) {
            return ((ServletRackContext) context).getRackFactory();
        }
        throw new IllegalStateException("not a servlet rack context");
    }
    
}
