/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

import org.jruby.exceptions.RaiseException;
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
    protected void afterException(
            final RackEnvironment request, 
            final Exception ex,
            final RackResponseEnvironment response) 
        throws IOException, RackException {
        
        RackApplication errorApp = getRackFactory().getErrorApplication();
        request.setAttribute(RackEnvironment.EXCEPTION, ex);
        try {
            errorApp.call(request).respond(response);
        }
        catch (Exception e) {
            // allow the error app to re-throw Ruby/JRuby-Rack exceptions :
            if (e instanceof RackException) throw (RackException) e;
            //if (e instanceof RaiseException) throw (RaiseException) e;
            // TODO seems redundant maybe we should let the container decide ?!
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
