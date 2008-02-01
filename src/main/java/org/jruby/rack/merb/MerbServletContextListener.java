package org.jruby.rack.merb;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SharedRackApplicationFactory;

/**
 *
 * @author dudley
 */
public class MerbServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory() {
        return new SharedRackApplicationFactory(new MerbRackApplicationFactory());
    }
}
