/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.servlet.DefaultServletRackContext;
import org.jruby.rack.servlet.ServletRackConfig;
import org.jruby.rack.servlet.ServletRackContext;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Web application lifecycle listener.
 * @author nicksieger
 */
public class RackServletContextListener implements ServletContextListener {
    
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
        ServletRackConfig config = new ServletRackConfig(ctx);
        final RackApplicationFactory fac = newApplicationFactory(config);
        ctx.setAttribute(RackApplicationFactory.FACTORY, fac);
        ServletRackContext rackContext = new DefaultServletRackContext(config);
        ctx.setAttribute(RackApplicationFactory.RACK_CONTEXT, rackContext);
        try {
            fac.init(rackContext);
        } catch (Exception ex) {
            ctx.log("Error: application initialization failed", ex);
        }
    }

    public void contextDestroyed(ServletContextEvent ctxEvent) {
        ServletContext ctx = ctxEvent.getServletContext();
        final RackApplicationFactory fac =
                (RackApplicationFactory) ctx.getAttribute(RackApplicationFactory.FACTORY);
        if (fac != null) {
            fac.destroy();
            ctx.removeAttribute(RackApplicationFactory.FACTORY);
            ctx.removeAttribute(RackApplicationFactory.RACK_CONTEXT);
        }
    }

    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        if (factory != null) {
            return factory;
        }
        return new SharedRackApplicationFactory(new DefaultRackApplicationFactory());
    }
    
}
