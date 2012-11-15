/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.merb;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SharedRackApplicationFactory;

/**
 * @deprecated Merb support is deprecated and will be removed in 1.2
 * @author dudley
 */
@Deprecated
public class MerbServletContextListener extends RackServletContextListener {
    @Override
    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        return new SharedRackApplicationFactory(
            new MerbRackApplicationFactory()
        );
    }
}
