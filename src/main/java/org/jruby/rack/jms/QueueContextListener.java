/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import org.jruby.rack.servlet.ServletRackContext;

/**
 *
 * @author nicksieger
 */
public class QueueContextListener implements ServletContextListener {
    private QueueManagerFactory factory;
    
    public QueueContextListener() {
        this.factory = null;
    }
    
    public QueueContextListener(QueueManagerFactory qmf) {
        this.factory = qmf;
    }
    
    public void contextInitialized(ServletContextEvent event) {
        final ServletContext servletContext = event.getServletContext();
        try {
            QueueManager qm = newQueueManagerFactory().newQueueManager();
            qm.init(new ServletRackContext(servletContext));
            servletContext.setAttribute(QueueManager.MGR_KEY, qm);
        } catch (Exception e) {
            servletContext.log("Error initializing queue manager:" + e.getMessage(), e);
        }
    }

    public void contextDestroyed(ServletContextEvent event) {
        QueueManager qm = (QueueManager) event.getServletContext().getAttribute(QueueManager.MGR_KEY);
        if (qm != null) {
            event.getServletContext().removeAttribute(QueueManager.MGR_KEY);
            qm.destroy();
        }
    }

    private QueueManagerFactory newQueueManagerFactory() {
        if (factory != null) {
            return factory;
        }
        return new QueueManagerFactory() {
            public QueueManager newQueueManager() {
                return new DefaultQueueManager();
            }
        };
    }
}
