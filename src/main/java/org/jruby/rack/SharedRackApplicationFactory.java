/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;

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

    public void init(ServletContext servletContext) throws ServletException {
        try {
            realFactory.init(servletContext);
            application = realFactory.getApplication();
        } catch (final Exception ex) {
            application = new RackApplication() {
                public void init() throws RackInitializationException { }
                public RackResponse call(ServletRequest env) {
                    env.setAttribute(RackDispatcher.EXCEPTION, ex);
                    return realFactory.getErrorApplication().call(env);
                }
                public void destroy() { }
                public Ruby getRuntime() { throw new UnsupportedOperationException("not supported"); }
            };
            servletContext.log("unable to create shared application instance", ex);
            throw new ServletException(ex);
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
