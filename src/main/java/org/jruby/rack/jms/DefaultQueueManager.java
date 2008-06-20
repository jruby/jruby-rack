/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import javax.jms.MessageListener;
import javax.servlet.ServletContext;

/**
 *
 * @author nicksieger
 */
public class DefaultQueueManager implements QueueManager {
    public DefaultQueueManager() {
    }

    public void init(ServletContext context) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    public void addListener(String queueName, MessageListener listener) {
        throw new UnsupportedOperationException("Not supported yet.");
    }

    public void destroy() {
        throw new UnsupportedOperationException("Not supported yet.");
    }
}
