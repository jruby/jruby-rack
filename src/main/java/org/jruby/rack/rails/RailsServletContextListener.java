/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import javax.servlet.ServletContext;

import org.jruby.rack.PoolingRackApplicationFactory;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SharedRackApplicationFactory;
import org.jruby.rack.SerialPoolingRackApplicationFactory;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory(ServletContext context) {
        Integer maxRuntimes = null;
        try {
            maxRuntimes = Integer.parseInt(context.getInitParameter("jruby.max.runtimes").toString());
        } catch (Exception e) {
        }
        if (maxRuntimes != null && maxRuntimes == 1) {
            return new SharedRackApplicationFactory(new RailsRackApplicationFactory());
        } else {
            boolean serial = false;
            try {
                serial = Boolean.parseBoolean(context.getInitParameter("jruby.init.serial").toString());
            } catch (Exception e) {
            }
            
            if(serial) {
                return new SerialPoolingRackApplicationFactory(new RailsRackApplicationFactory());
            } else {
                return new PoolingRackApplicationFactory(new RailsRackApplicationFactory());
            }
        }
    }
}
