/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

/**
 *
 * @author nicksieger
 */
public class DefaultQueueManagerFactory implements QueueManagerFactory {
    public QueueManager newQueueManager() {
        return new DefaultQueueManager();
    }
}
