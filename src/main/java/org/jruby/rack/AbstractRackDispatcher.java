/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
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
public abstract class AbstractRackDispatcher implements RackDispatcher {
    
    protected final RackContext context;

    public AbstractRackDispatcher(RackContext context) {
        this.context = context;
    }

    public void process(RackEnvironment request, RackResponseEnvironment response)
        throws IOException {

        RackApplication app = null;
        try {
            app = getApplication();
            app.call(request).respond(response);
        } 
        catch (Exception re) {
            handleException(re, request, response);
        } 
        finally {
            afterProcess(app);
        }
    }

    private void handleException(
            Exception re, RackEnvironment request,
            RackResponseEnvironment response) throws IOException {
        
        if (response.isCommitted()) {
            context.log("Error: Couldn't handle error: response committed", re);
            return;
        }
        response.reset();
        context.log("Application Error", re);

        afterException(request, re, response);
    }

    protected abstract void afterProcess(RackApplication app) throws IOException;
    
    protected abstract RackApplication getApplication() throws RackInitializationException;
    
    protected abstract void afterException(RackEnvironment request, 
            Exception re, RackResponseEnvironment response) throws IOException;
    
}
