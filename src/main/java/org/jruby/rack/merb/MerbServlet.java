package org.jruby.rack.merb;

import org.jruby.rack.RackServlet;
import org.jruby.rack.SharedRackApplicationFactory;

/**
 *
 * @author dudley
 */
public class MerbServlet extends RackServlet {
    public MerbServlet() {
        super(new SharedRackApplicationFactory( 
                new MerbRackApplicationFactory()));
    }
}
