/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import javax.jms.ConnectionFactory;
import javax.servlet.ServletContext;

/**
 *
 * @author nicksieger
 */
public interface QueueManager {
    void init(ServletContext context) throws Exception;
    void listen(String queueName, String rubyClassName);
    ConnectionFactory getConnectionFactory();
    void destroy();
}
