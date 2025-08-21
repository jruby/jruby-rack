/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import org.jruby.rack.PoolingRackApplicationFactory;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SerialPoolingRackApplicationFactory;
import org.jruby.rack.SharedRackApplicationFactory;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {
    
    @Override
    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        final RackApplicationFactory factory = new RailsRackApplicationFactory();
        final Integer maxRuntimes = config.getMaximumRuntimes();
        // TODO maybe after Rails 4 is out switch to shared by default as well !
        if ( maxRuntimes != null && maxRuntimes.intValue() == 1 ) {
            return new SharedRackApplicationFactory(factory);
        } 
        else {
            return config.isSerialInitialization() ?
                new SerialPoolingRackApplicationFactory(factory) :
                    new PoolingRackApplicationFactory(factory) ;
        }
    }
    
}
