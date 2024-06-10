/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.util.Queue;

import static org.jruby.rack.RackLogger.Level.*;

/**
 * Works like the pooling application factory, with the variation that it will
 * create all application instances (runtimes) serially, using no extra threads.
 *
 * @author Ola Bini &lt;ola.bini@gmail.com&gt;
 */
public class SerialPoolingRackApplicationFactory extends PoolingRackApplicationFactory {

    public SerialPoolingRackApplicationFactory(RackApplicationFactory factory) {
        super(factory);
    }

    @Override
    protected void launchInitialization(final Queue<RackApplication> apps) {
        while ( ! apps.isEmpty() ) {
            final RackApplication app = apps.remove();
            try {
                app.init();
                applicationPool.add(app);
                log(INFO, "added application to pool, size now = " + applicationPool.size());
            }
            catch (RackInitializationException e) {
                log(ERROR, "unable to initialize application", e);
            }
        }
    }

    @Override
    protected void waitTillPoolReady() {
        return; // waiting makes no sense here as we're initializing serialy
    }

}
