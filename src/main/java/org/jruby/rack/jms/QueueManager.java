/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import javax.jms.ConnectionFactory;
import org.jruby.rack.RackContext;

/**
 *
 * @author nicksieger
 */
public interface QueueManager {
    void init(RackContext context) throws Exception;
    void listen(String queueName);
    ConnectionFactory getConnectionFactory();
    Object lookup(String name) throws javax.naming.NamingException;
    void destroy();
}
