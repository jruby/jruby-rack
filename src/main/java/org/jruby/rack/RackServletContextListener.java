/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Web application lifecycle listener.
 * @author nicksieger
 */
public class RackServletContextListener implements ServletContextListener {
    public static final String FACTORY_KEY = "rack.factory";
    private final RackApplicationFactory factory;

    public RackServletContextListener() {
        factory = null;
    }

    /**
     * Not used by servlet container -- only for injecting a mock factory
     * for testing.
     */
    public RackServletContextListener(RackApplicationFactory factoryForTest) {
        factory = factoryForTest;
    }

    public void contextInitialized(ServletContextEvent ctxEvent) {
        ServletContext ctx = ctxEvent.getServletContext();
        final RackApplicationFactory fac = newApplicationFactory();
        ctx.setAttribute(FACTORY_KEY, fac);
        try {
            fac.init(ctx);
        } catch (Exception ex) {
            ctx.log("Application initialization failed", ex);
        }
    }

    public void contextDestroyed(ServletContextEvent ctxEvent) {
        ServletContext ctx = ctxEvent.getServletContext();
        final RackApplicationFactory fac =
                (RackApplicationFactory) ctx.getAttribute(FACTORY_KEY);
        if (fac != null) {
            fac.destroy();
            ctx.removeAttribute(FACTORY_KEY);
        }
    }

    protected RackApplicationFactory newApplicationFactory() {
        if (factory != null) {
            return factory;
        }

        return new SharedRackApplicationFactory(new DefaultRackApplicationFactory());
    }
}