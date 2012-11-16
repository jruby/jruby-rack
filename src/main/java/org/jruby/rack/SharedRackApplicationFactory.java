/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 *
 * @author nicksieger
 */
public class SharedRackApplicationFactory implements RackApplicationFactory,
    RackApplicationFactory.Decorator {
    
    private final RackApplicationFactory delegate;
    private RackApplication application;

    public SharedRackApplicationFactory(RackApplicationFactory delegate) {
        this.delegate = delegate;
    }

    public RackApplicationFactory getDelegate() {
        return delegate;
    }
    
    @Deprecated
    public RackApplicationFactory getRealFactory() {
        return getDelegate();
    }
    
    public void init(RackContext rackContext) throws RackInitializationException {
        try {
            delegate.init(rackContext);
            rackContext.log(RackLogger.INFO, "using a shared (threadsafe!) runtime");
            application = delegate.getApplication();
        }
        catch (Exception e) {
            rackContext.log(RackLogger.ERROR, "unable to create shared application instance", e);
            if (e instanceof RackInitializationException) throw ((RackInitializationException) e);
            throw new RackInitializationException("unable to create shared application instance", e);
        }
    }

    public RackApplication newApplication() throws RackInitializationException {
        return getApplication();
    }

    public RackApplication getApplication() throws RackInitializationException {
        return application;
    }

    public void finishedWithApplication(RackApplication app) {
    }

    public RackApplication getErrorApplication() {
        return delegate.getErrorApplication();
    }

    public void destroy() {
        if (application != null) {
            synchronized(this) {
                if (application != null) {
                    delegate.finishedWithApplication(application);
                    // DefaultRackAppFactory: application.destroy();
                }
            }
        }
        delegate.destroy();
    }
    
}
