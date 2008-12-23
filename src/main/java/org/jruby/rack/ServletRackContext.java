/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.ServletContext;

/**
 *
 * @author nicksieger
 */
public class ServletRackContext implements RackContext {
    private ServletContext context;

    public ServletRackContext(ServletContext context) {
        this.context = context;
    }

    public String getInitParameter(String key) {
        return context.getInitParameter(key);
    }

    public void log(String message) {
        context.log(message);
    }

    public void log(String message, Throwable ex) {
        context.log(message,ex);
    }

    public RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory) context.getAttribute(RackServletContextListener.FACTORY_KEY);
    }
}
