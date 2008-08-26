/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import javax.servlet.ServletContext;

import org.jruby.rack.PoolingRackApplicationFactory;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SharedRackApplicationFactory;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory(ServletContext context) {
        Integer maxRuntimes = null;
        try {
            maxRuntimes = Integer.parseInt(context.getAttribute("jruby.max.runtimes").toString());
        } catch (Exception e) {
        }
        if (maxRuntimes != null && maxRuntimes == 1) {
            return new SharedRackApplicationFactory(new RailsRackApplicationFactory());
        } else {
            return new PoolingRackApplicationFactory(new RailsRackApplicationFactory());
        }
    }
}
