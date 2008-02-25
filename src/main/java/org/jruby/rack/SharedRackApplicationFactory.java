/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;

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
        } catch (RackInitializationException ex) {
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
