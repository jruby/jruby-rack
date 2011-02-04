/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import org.jruby.rack.*;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        Integer maxRuntimes = config.getMaximumRuntimes();
        if (maxRuntimes != null && maxRuntimes == 1) {
            return new SharedRackApplicationFactory(new RailsRackApplicationFactory());
        } else {
            if (config.isSerialInitialization()) {
                return new SerialPoolingRackApplicationFactory(new RailsRackApplicationFactory());
            } else {
                return new PoolingRackApplicationFactory(new RailsRackApplicationFactory());
            }
        }
    }
}
