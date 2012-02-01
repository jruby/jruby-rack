/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import org.jruby.rack.RackContext;

import javax.jms.ConnectionFactory;

/**
 *
 * @author nicksieger
 */
public interface QueueManager {
    String MGR_KEY = "rack.queue.manager";

    void init(RackContext context) throws Exception;
    void listen(String queueName);
    void close(String queueName);
    ConnectionFactory getConnectionFactory();
    Object lookup(String name) throws javax.naming.NamingException;
    void destroy();
}
