/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
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
    private RackApplicationFactory realFactory;
    private RackApplication application;

    public SharedRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public void init(RackContext rackContext) throws RackInitializationException {
        try {
            realFactory.init(rackContext);
            application = realFactory.getApplication();
        } catch (final Exception ex) {
            application = new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResponse call(RackEnvironment env) {
                    env.setAttribute(RackEnvironment.EXCEPTION, ex);
                    return realFactory.getErrorApplication().call(env);
                }
                public void destroy() { }
                public Ruby getRuntime() { throw new UnsupportedOperationException("not supported"); }
            };
            rackContext.log("unable to create shared application instance", ex);
            throw new RackInitializationException("unable to create shared application instance", ex);
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
    }
}
