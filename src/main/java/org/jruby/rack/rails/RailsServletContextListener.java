/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import org.jruby.rack.PoolingRackApplicationFactory;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory() {
        return new PoolingRackApplicationFactory(
                new RailsRackApplicationFactory());
    }
}
