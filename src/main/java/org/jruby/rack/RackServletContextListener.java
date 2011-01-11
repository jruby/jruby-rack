/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.servlet.ServletRackContext;
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
        final RackApplicationFactory fac = newApplicationFactory(ctx);
        ctx.setAttribute(FACTORY_KEY, fac);
        try {
            fac.init(new ServletRackContext(ctx));
        } catch (Exception ex) {
            ctx.log("Error: application initialization failed", ex);
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

    protected RackApplicationFactory newApplicationFactory(ServletContext context) {
        if (factory != null) {
            return factory;
        }

        return new SharedRackApplicationFactory(new DefaultRackApplicationFactory());
    }
}