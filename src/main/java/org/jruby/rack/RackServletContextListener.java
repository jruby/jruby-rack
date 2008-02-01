/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
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
        try {
            final RackApplicationFactory fac = newApplicationFactory();
            fac.init(ctx);
            ctx.setAttribute(FACTORY_KEY, fac);
        } catch (Exception ex) {
            ctx.log("Application initialization failed: " + ex.getMessage());
        }
    }

    public void contextDestroyed(ServletContextEvent ctxEvent) {
        ServletContext ctx = ctxEvent.getServletContext();
        final RackApplicationFactory fac =
                (RackApplicationFactory) ctx.getAttribute(FACTORY_KEY);
        fac.destroy();
        ctx.removeAttribute(FACTORY_KEY);
    }

    protected RackApplicationFactory newApplicationFactory() {
        if (factory != null) {
            return factory;
        }

        return new SharedRackApplicationFactory(new DefaultRackApplicationFactory());
    }
}