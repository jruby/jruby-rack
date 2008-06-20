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
public interface QueueManager {
    void init(ServletContext context);
    void addListener(String queueName, MessageListener listener);
    void destroy();
}
