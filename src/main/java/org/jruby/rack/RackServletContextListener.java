/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;

import org.jruby.rack.servlet.DefaultServletRackContext;
import org.jruby.rack.servlet.ServletRackConfig;
import org.jruby.rack.servlet.ServletRackContext;

import static org.jruby.rack.DefaultRackConfig.isThrowInitException;

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
    RackServletContextListener(RackApplicationFactory factory) {
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
        catch (RuntimeException e) {
            handleInitializationException(e, factory, rackContext);
        }
    }

    public void contextDestroyed(final ServletContextEvent event) {
        final ServletContext context = event.getServletContext();
        final RackApplicationFactory factory =
                (RackApplicationFactory) context.getAttribute(RackApplicationFactory.FACTORY);
        if ( factory != null ) {
            context.removeAttribute(RackApplicationFactory.FACTORY);
            context.removeAttribute(RackApplicationFactory.RACK_CONTEXT);
            factory.destroy();
        }
    }

    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        if (factory != null) return factory; // only != null while testing

        final RackApplicationFactory factory = new DefaultRackApplicationFactory();
        final Integer maxRuntimes = config.getMaximumRuntimes();
        // for backwards compatibility when runtime mix/max values not specified
        // we assume a single shared (threadsafe) runtime to be used :
        if ( maxRuntimes == null || maxRuntimes.intValue() == 1 ) {
            return new SharedRackApplicationFactory(factory);
        } 
        else {
            return config.isSerialInitialization() ?
                new SerialPoolingRackApplicationFactory(factory) :
                    new PoolingRackApplicationFactory(factory) ;
        }
    }
    
    protected void handleInitializationException(
            final Exception e,
            final RackApplicationFactory factory,
            final ServletRackContext rackContext) {
        // TODO for backwards compat we do not throw (by default) but should :
        if ( isThrowInitException(rackContext.getConfig()) ) {
            if (e instanceof RuntimeException) {
                throw (RuntimeException) e;
            }
            throw RackInitializationException.wrap(e);
        }
        // NOTE: factory should have already logged the error ...
        rackContext.log(RackLogger.ERROR, "initialization failed", e);
    }
    
}
