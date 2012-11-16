/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

/**
 * Shared application factory that only creates a single application instance.
 * This factory implementation is the most effective on performance and esp. 
 * memory consumption but the underlying Ruby code in the application is assumed
 * to be thread-safe. If you're using a Rails application make sure it is 
 * configured as <code>config.threadsafe!</code>.
 * 
 * @author nicksieger
 */
public class SharedRackApplicationFactory extends RackApplicationFactoryDecorator {
    
    private RackApplication application;

    public SharedRackApplicationFactory(RackApplicationFactory delegate) {
        super(delegate);
    }
    
    @Override
    protected void doInit() throws RackInitializationException {
        super.doInit(); // delegate.init(rackContext);
        log(RackLogger.INFO, "using a shared (threadsafe!) runtime");
        application = getDelegate().getApplication();
    }

    @Override
    protected RackApplication getApplicationImpl() {
        return application;
    }

    /**
     * We do not create any new applications since we're sharing.
     * @see #getApplication() 
     * @return an application
     */
    public RackApplication newApplication() {
        return getApplication();
    }
    
    public void finishedWithApplication(RackApplication app) {
        /* NOOP we keep the shared application until #destroy() */
    }

    @Override
    public void destroy() {
        if (application != null) {
            synchronized(this) {
                if (application != null) {
                    getDelegate().finishedWithApplication(application);
                    // DefaultRackAppFactory: application.destroy();
                }
            }
        }
        super.destroy(); // delegate.destroy();
    }
    
}
