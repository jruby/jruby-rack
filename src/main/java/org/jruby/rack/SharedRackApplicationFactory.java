/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.Ruby;

/**
 *
 * @author nicksieger
 */
public class SharedRackApplicationFactory implements RackApplicationFactory {
    
    private final RackApplicationFactory realFactory;
    private RackApplication application;

    public SharedRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public RackApplicationFactory getRealFactory() {
        return realFactory;
    }
    
    public void init(RackContext rackContext) throws RackInitializationException {
        try {
            realFactory.init(rackContext);
            rackContext.log(RackLogger.INFO, "using a shared (threadsafe!) runtime");
            application = realFactory.getApplication();
        } catch (final Exception e) {
            application = new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResponse call(RackEnvironment env) {
                    env.setAttribute(RackEnvironment.EXCEPTION, e);
                    return realFactory.getErrorApplication().call(env);
                }
                public void destroy() { }
                public Ruby getRuntime() { throw new UnsupportedOperationException("not supported"); }
            };
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
        return realFactory.getErrorApplication();
    }

    public void destroy() {
        application.destroy();
        realFactory.destroy();
    }
}
