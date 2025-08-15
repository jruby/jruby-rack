#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))
require 'jruby/rack/queues'

describe JRuby::Rack::Queues do

  before :each do
    JRuby::Rack.context = @servlet_context
    @queue_manager = double "queue manager"
    allow(@servlet_context).to receive(:getAttribute).and_return @queue_manager
    @registry = JRuby::Rack::Queues::QueueRegistry.new
  end

  after(:all) { JRuby::Rack.context = nil }

  def mock_connection
    conn_factory = double "connection factory"
    expect(@queue_manager).to receive(:getConnectionFactory).and_return conn_factory
    conn = double "connection"
    expect(conn_factory).to receive(:createConnection).ordered.and_return conn
    conn
  end

  def mock_message(text)
    message = double "message"
    allow(message).to receive(:getBooleanProperty).and_return false
    allow(message).to receive(:getText).and_return text
    message
  end

  it "#with_jms_connection should yield a JMS connection" do
    conn = mock_connection
    expect(conn).to receive(:createMessage).ordered
    expect(conn).to receive(:close).ordered

    @registry.with_jms_connection do |c|
      c.createMessage
    end
  end

  it "#publish_message should create a session, producer and message" do
    conn = mock_connection
    queue = double "queue"
    session = double "session"
    producer = double "producer"
    message = double "message"
    expect(@queue_manager).to receive(:lookup).with("FooQ").and_return queue
    expect(conn).to receive(:createSession).and_return session
    expect(conn).to receive(:close)
    expect(session).to receive(:createProducer).with(queue).and_return producer
    expect(session).to receive(:createBytesMessage).and_return message
    expect(message).to receive(:setBooleanProperty).with(JRuby::Rack::Queues::MARSHAL_PAYLOAD, true)
    expect(message).to receive(:writeBytes)
    expect(producer).to receive(:send).with(message)
    @registry.publish_message("FooQ", Object.new)
  end

  it "#publish_message should accept a block that allows construction of the message" do
    conn = mock_connection
    queue = double "queue"
    session = double "session"
    producer = double "producer"
    message = double "message"
    expect(@queue_manager).to receive(:lookup).with("FooQ").and_return queue
    expect(conn).to receive(:createSession).and_return session
    expect(conn).to receive(:close)
    expect(session).to receive(:createProducer).with(queue).and_return producer
    expect(session).to receive(:createTextMessage).and_return message
    expect(producer).to receive(:send).with(message)
    @registry.publish_message "FooQ" do |sess|
      session.createTextMessage
    end
  end

  it "#publish_message should create a text message when handed a string message argument" do
    conn = mock_connection
    queue = double "queue"
    session = double "session"
    producer = double "producer"
    message = double "message"
    expect(@queue_manager).to receive(:lookup).with("FooQ").and_return queue
    expect(conn).to receive(:createSession).and_return session
    expect(conn).to receive(:close)
    expect(session).to receive(:createProducer).with(queue).and_return producer
    expect(session).to receive(:createTextMessage).and_return message
    expect(message).to receive(:setText).with("hello")
    expect(producer).to receive(:send).with(message)
    @registry.publish_message "FooQ", "hello"
  end

  it "#register_listener should ensure the queue manager is listening and store the listener" do
    listener = double "listener"
    expect(@queue_manager).to receive(:listen).with "FooQ"
    @registry.register_listener "FooQ", listener
    expect(listener).to receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "#unregister_listener should remove the listener and close the queue" do
    listener = double "listener"
    expect(@queue_manager).to receive(:listen).with "FooQ"
    @registry.register_listener "FooQ", listener
    expect(@queue_manager).to receive(:close).with "FooQ"
    @registry.unregister_listener(listener)
    expect { @registry.receive_message("FooQ", mock_message("msg")) }.to raise_error(RuntimeError)
  end

  it "#receive_message should raise an exception if there is no listener for the queue" do
    expect { @registry.receive_message("NoQ", "hi") }.to raise_error(RuntimeError)
  end

  it "#register_listener should allow multiple listeners per queue" do
    listener1 = double "listener 1"
    listener2 = double "listener 2"
    allow(@queue_manager).to receive(:listen)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    expect(listener1).to receive(:call).with("hi")
    expect(listener2).to receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "#register_listener should only allow a given listener to be registered once per queue" do
    listener = double "listener"
    allow(@queue_manager).to receive(:listen)
    @registry.register_listener "FooQ", listener
    @registry.register_listener "FooQ", listener
    expect(listener).to receive(:call).with("hi").once
    @registry.receive_message("FooQ", mock_message("hi"))
  end


  it "#unregister_listener should only remove the given listener and not close the queue" do
    listener1 = double "listener 1"
    listener2 = double "listener 2"
    allow(@queue_manager).to receive(:listen)
    expect(@queue_manager).not_to receive(:close)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    @registry.unregister_listener listener2
    expect(listener1).to receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "should deliver the message to all listeners, but raise the first of any exceptions raised" do
    listener1 = double "listener 1"
    listener2 = double "listener 2"
    allow(@queue_manager).to receive(:listen)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    expect(listener1).to receive(:call).with("hi").and_raise "error 1"
    expect(listener2).to receive(:call).with("hi").and_raise "error 2"
    expect { @registry.receive_message("FooQ", mock_message("hi")) }.to raise_error("error 1")
  end
end

describe JRuby::Rack::Queues::MessageDispatcher do
  before :each do
    $servlet_context = @servlet_context
    @message = double "JMS message"
    @listener = double "listener"
  end

  it "should dispatch to an object that responds to #on_jms_message and provide the JMS message" do
    expect(@listener).to receive(:on_jms_message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should unmarshal the message if the marshal payload property is set" do
    expect(@message).to receive(:getBooleanProperty).with(JRuby::Rack::Queues::MARSHAL_PAYLOAD).and_return true
    first = false
    expect(@message).to receive(:readBytes).twice do |byte_array|
      if first
        -1
      else
        first = true
        bytes = Marshal.dump("hello").to_java_bytes
        java.lang.System.arraycopy bytes, 0, byte_array, 0, bytes.length
        bytes.length
      end
    end
    expect(@listener).to receive(:call).with("hello")
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should grab text out of the message if it responds to #getText" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect(@message).to receive(:getText).and_return "hello"
    expect(@listener).to receive(:call).with("hello")
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should pass the message through otherwise" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect(@listener).to receive(:call).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should dispatch to a listener that responds to #call" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect(@listener).to receive(:call).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should dispatch to a listener that responds to #on_message" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect(@listener).to receive(:on_message).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  class Listener
    def self.message; @@message; end
    def on_message(msg)
      @@message = msg
    end
  end

  it "should instantiate a class and dispatch to it" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    JRuby::Rack::Queues::MessageDispatcher.new(Listener).dispatch(@message)
    expect(Listener.message).to eq @message
  end

  it "should log and re-raise any exceptions that are raised during dispatch" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect(@listener).to receive(:on_message).and_raise "something went wrong"
    expect(@servlet_context).to receive(:log).with(/something went wrong/)
    expect {
      JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
    }.to raise_error(RuntimeError)
  end

  it "should raise an exception if it was unable to dispatch to anything" do
    allow(@message).to receive(:getBooleanProperty).and_return false
    expect {
      JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
    }.to raise_error(RuntimeError)
  end
end
