#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

java_import org.jruby.rack.jms.QueueContextListener
java_import org.jruby.rack.jms.QueueManager
java_import org.jruby.rack.jms.DefaultQueueManager

describe QueueContextListener do
  before :each do
    @qmf = double "queue manager factory"
    @qm = QueueManager.impl {}
    @listener_event = javax.servlet.ServletContextEvent.new @servlet_context
    @listener = QueueContextListener.new @qmf
  end

  it "should create a new QueueManager, initialize it and store it in the application context" do
    expect(@qmf).to receive(:newQueueManager).ordered.and_return @qm
    expect(@qm).to receive(:init).ordered
    expect(@servlet_context).to receive(:setAttribute).with(QueueManager::MGR_KEY, @qm).ordered
    @listener.contextInitialized(@listener_event)
  end

  it "should capture exceptions during initialization and log them to the servlet context" do
    expect(@qmf).to receive(:newQueueManager).and_return @qm
    expect(@qm).to receive(:init).and_raise StandardError.new("something happened!")
    @listener.contextInitialized(@listener_event)
  end

  it "should remove the QueueManager and destroy it" do
    qm = QueueManager.impl {}
    expect(@servlet_context).to receive(:getAttribute).with(QueueManager::MGR_KEY).and_return qm
    expect(@servlet_context).to receive(:removeAttribute).with(QueueManager::MGR_KEY)
    expect(qm).to receive(:destroy)
    @listener.contextDestroyed(@listener_event)
  end
end

describe DefaultQueueManager do
  before :each do
    @connection_factory = double "jms connection factory"
    @context = double "jndi context"
    @queue_manager = DefaultQueueManager.new(@connection_factory, @context)
    @queue_manager.init(@rack_context)
  end

  it "should set up a connection with a message listener" do
    app_factory = Java::OrgJRubyRack::RackApplicationFactory.impl {}
    expect(@rack_context).to receive(:getRackFactory).and_return app_factory
    conn = double "connection"
    expect(@connection_factory).to receive(:createConnection).and_return conn
    session = double "session"
    expect(conn).to receive(:createSession).and_return session
    dest = javax.jms.Destination.impl {}
    expect(@context).to receive(:lookup).with("myqueue").and_return dest
    consumer = double "consumer"
    expect(session).to receive(:createConsumer).and_return consumer
    expect(consumer).to receive(:setMessageListener)
    expect(conn).to receive(:start)
    @queue_manager.listen("myqueue")
  end

  it "should shutdown a connection when closed" do
    app_factory = Java::OrgJRubyRack::RackApplicationFactory.impl {}
    allow(@rack_context).to receive(:getRackFactory).and_return app_factory
    conn = double "connection"
    allow(@connection_factory).to receive(:createConnection).and_return conn
    session = double "session"
    allow(conn).to receive(:createSession).and_return session
    dest = javax.jms.Destination.impl {}
    allow(@context).to receive(:lookup).with("myqueue").and_return dest
    consumer = double "consumer"
    allow(session).to receive(:createConsumer).and_return consumer
    allow(consumer).to receive(:setMessageListener)
    expect(conn).to receive(:start)
    @queue_manager.listen("myqueue")

    expect(conn).to receive(:close)
    @queue_manager.close("myqueue")
  end
end
