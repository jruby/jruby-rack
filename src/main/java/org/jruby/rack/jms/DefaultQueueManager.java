/*
 * Copyright 2007-2008 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.jms;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import javax.jms.Message;
import javax.jms.MessageListener;
import javax.jms.Connection;
import javax.jms.ConnectionFactory;
import javax.jms.Destination;
import javax.jms.MessageConsumer;
import javax.jms.Session;
import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.servlet.ServletContext;
import org.jruby.Ruby;
import org.jruby.RubyObjectAdapter;
import org.jruby.RubyRuntimeAdapter;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackServletContextListener;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class DefaultQueueManager implements QueueManager {
    private ConnectionFactory connectionFactory = null;
    private ServletContext context;
    private Context jndiContext;
    private Map<String,Connection> queues = new HashMap<String,Connection>();
    private RubyRuntimeAdapter rubyRuntimeAdapter = JavaEmbedUtils.newRuntimeAdapter();
    private RubyObjectAdapter rubyObjectAdapter = JavaEmbedUtils.newObjectAdapter();

    public DefaultQueueManager() {
    }

    public DefaultQueueManager(ConnectionFactory qcf) {
        this.connectionFactory = qcf;
    }
    
    public void init(ServletContext context) {
        this.context = context;
        String jndiName = context.getInitParameter("jms.jndi.connection.factory");
        if (jndiName != null && connectionFactory == null) {
            try {
                jndiContext = new InitialContext();
                this.connectionFactory = (ConnectionFactory) jndiContext.lookup(jndiName);
            } catch (NamingException ex) {
                context.log("error looking up queue connection factory '"+jndiName+"'", ex);
            }
        }
    }

    public synchronized void listen(String queueName, String rubyClassName) {
        Connection conn = queues.get(queueName);
        if (conn == null) {
            try {
                conn = connectionFactory.createConnection();
                Session session = conn.createSession(false, Session.AUTO_ACKNOWLEDGE);
                Destination dest = (Destination) jndiContext.lookup(queueName);
                MessageConsumer consumer = session.createConsumer(dest);
                consumer.setMessageListener(new RubyObjectMessageListener(rubyClassName));
                queues.put(queueName, conn);
                conn.start();
            } catch (Exception e) {
                context.log("Unable to listen to '"+queueName+"': " + e.getMessage(), e);
            }
        // } else { ... already listening on that queue
        }
    }

    public ConnectionFactory getConnectionFactory() {
        return connectionFactory;
    }
    
    public void destroy() {
        for (Iterator it = queues.entrySet().iterator(); it.hasNext();) {
            Map.Entry<String,Connection> entry = (Map.Entry<String, Connection>) it.next();
            try {
                entry.getValue().close();
            } catch (Exception e) {
                context.log("exception while closing connection: " + e.getMessage(), e);
            }
        }
        queues.clear();
        connectionFactory = null;
    }

    private class RubyObjectMessageListener implements MessageListener {
        private String className;
        public RubyObjectMessageListener(String rubyClassName) {
            this.className = rubyClassName;
        }

        public void onMessage(Message message) {
            final RackApplicationFactory rackFactory = getRackFactory();
            RackApplication app = null;
            try {
                app = rackFactory.getApplication();
                Ruby runtime = app.getRuntime();
                IRubyObject obj = rubyRuntimeAdapter.eval(runtime, className + ".new");
                rubyObjectAdapter.callMethod(obj, "on_jms_message", JavaEmbedUtils.javaToRuby(runtime, message));
            } catch (Exception e) {
                context.log("exception during message reception: " + e.getMessage(), e);
            } finally {
                if (app != null) {
                    rackFactory.finishedWithApplication(app);
                }
            }
        }

        private RackApplicationFactory getRackFactory() {
            return (RackApplicationFactory)
                context.getAttribute(RackServletContextListener.FACTORY_KEY);
        }
    }
}