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

    /**
     * Used by web container.
     */
    public RackServletContextListener() {
        this.factory = null;
    }

    /**
     * Only for injecting a mock factory for testing.
     */
    public RackServletContextListener(RackApplicationFactory factory) {
        this.factory = factory;
    }

    public void contextInitialized(final ServletContextEvent event) {
        final ServletContext context = event.getServletContext();
        final ServletRackConfig config = new ServletRackConfig(context);
        final RackApplicationFactory factory = newApplicationFactory(config);
        context.setAttribute(RackApplicationFactory.FACTORY, factory);
        final ServletRackContext rackContext = new DefaultServletRackContext(config);
        context.setAttribute(RackApplicationFactory.RACK_CONTEXT, rackContext);
        try {
            factory.init(rackContext);
        } 
        catch (Exception e) {
            handleInitializationException(e, factory, rackContext);
        }
    }

    public void contextDestroyed(ServletContextEvent ctxEvent) {
        final ServletContext context = ctxEvent.getServletContext();
        final RackApplicationFactory factory =
                (RackApplicationFactory) context.getAttribute(RackApplicationFactory.FACTORY);
        if (factory != null) {
            factory.destroy();
            context.removeAttribute(RackApplicationFactory.FACTORY);
            context.removeAttribute(RackApplicationFactory.RACK_CONTEXT);
        }
    }

    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        if (factory != null) {
            return factory;
        }
        return new SharedRackApplicationFactory(new DefaultRackApplicationFactory());
    }
 
    protected void handleInitializationException(
            final Exception e,
            final RackApplicationFactory factory,
            final ServletRackContext rackContext) {
        rackContext.log("Error: application initialization failed", e);
    }
    
}
