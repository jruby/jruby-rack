/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.rails;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;

/**
 *
 * @author nicksieger
 */
public class RailsServletContextListener extends RackServletContextListener {

    @Override
    protected RackApplicationFactory getRealRackApplicationFactoryImpl() {
        return new RailsRackApplicationFactory();
    }
}
