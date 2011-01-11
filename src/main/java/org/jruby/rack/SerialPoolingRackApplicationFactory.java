/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.util.Queue;

/**
 * Works like the pooling application factory, with the variation that it will
 * create all runtimes serially, using no extra threads.
 *
 * @author Ola Bini <ola.bini@gmail.com>
 */
public class SerialPoolingRackApplicationFactory extends PoolingRackApplicationFactory {
    public SerialPoolingRackApplicationFactory(RackApplicationFactory factory) {
        super(factory);
    }

    protected void fillInitialPool() throws RackInitializationException {
        Queue<RackApplication> apps = createApplications();
        launchInitialization(apps);
    }

    protected void launchInitialization(final Queue<RackApplication> apps) {
        while (true) {
            RackApplication app = null;
            if (apps.isEmpty()) {
                break;
            }
            app = apps.remove();

            try {
                app.init();
                applicationPool.add(app);
                rackContext.log("Info: add application to the pool. size now = " + applicationPool.size());
            } catch (RackInitializationException ex) {
                rackContext.log("Error: unable to initialize application", ex);
            }
        }
    }
}

