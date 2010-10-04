#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'action_controller'
require 'active_record'
require 'jruby/rack/queues'

describe JRuby::Rack::Queues do
  before :each do
    $servlet_context = @servlet_context
    @queue_manager = mock "queue manager"
    @servlet_context.stub!(:getAttribute).and_return @queue_manager
    @registry = JRuby::Rack::Queues::QueueRegistry.new
  end

  def mock_connection
    conn_factory = mock "connection factory"
    @queue_manager.should_receive(:getConnectionFactory).and_return conn_factory
    conn = mock "connection"
    conn_factory.should_receive(:createConnection).ordered.and_return conn
    conn
  end

  def mock_message(text)
    message = mock "message"
    message.stub!(:getBooleanProperty).and_return false
    message.stub!(:getText).and_return text
    message
  end

  it "#with_jms_connection should yield a JMS connection" do
    conn = mock_connection
    conn.should_receive(:createMessage).ordered
    conn.should_receive(:close).ordered

    @registry.with_jms_connection do |c|
      c.createMessage
    end
  end

  it "#publish_message should create a session, producer and message" do
    conn = mock_connection
    queue = mock "queue"
    session = mock "session"
    producer = mock "producer"
    message = mock "message"
    @queue_manager.should_receive(:lookup).with("FooQ").and_return queue
    conn.should_receive(:createSession).and_return session
    conn.should_receive(:close)
    session.should_receive(:createProducer).with(queue).and_return producer
    session.should_receive(:createBytesMessage).and_return message
    message.should_receive(:setBooleanProperty).with(JRuby::Rack::Queues::MARSHAL_PAYLOAD, true)
    message.should_receive(:writeBytes)
    producer.should_receive(:send).with(message)
    @registry.publish_message("FooQ", Object.new)
  end

  it "#publish_message should accept a block that allows construction of the message" do
    conn = mock_connection
    queue = mock "queue"
    session = mock "session"
    producer = mock "producer"
    message = mock "message"
    @queue_manager.should_receive(:lookup).with("FooQ").and_return queue
    conn.should_receive(:createSession).and_return session
    conn.should_receive(:close)
    session.should_receive(:createProducer).with(queue).and_return producer
    session.should_receive(:createTextMessage).and_return message
    producer.should_receive(:send).with(message)
    @registry.publish_message "FooQ" do |sess|
      session.createTextMessage
    end
  end

  it "#publish_message should create a text message when handed a string message argument" do
    conn = mock_connection
    queue = mock "queue"
    session = mock "session"
    producer = mock "producer"
    message = mock "message"
    @queue_manager.should_receive(:lookup).with("FooQ").and_return queue
    conn.should_receive(:createSession).and_return session
    conn.should_receive(:close)
    session.should_receive(:createProducer).with(queue).and_return producer
    session.should_receive(:createTextMessage).and_return message
    message.should_receive(:setText).with("hello")
    producer.should_receive(:send).with(message)
    @registry.publish_message "FooQ", "hello"
  end

  it "#register_listener should ensure the queue manager is listening and store the listener" do
    listener = mock "listener"
    @queue_manager.should_receive(:listen).with "FooQ"
    @registry.register_listener "FooQ", listener
    listener.should_receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "#unregister_listener should remove the listener and close the queue" do
    listener = mock "listener"
    @queue_manager.should_receive(:listen).with "FooQ"
    @registry.register_listener "FooQ", listener
    @queue_manager.should_receive(:close).with "FooQ"
    @registry.unregister_listener(listener)
    lambda { @registry.receive_message("FooQ", mock_message("msg")) }.should raise_error
  end

  it "#receive_message should raise an exception if there is no listener for the queue" do
    lambda { @registry.receive_message("NoQ", "hi") }.should raise_error
  end

  it "#register_listener should allow multiple listeners per queue" do
    listener1 = mock "listener 1"
    listener2 = mock "listener 2"
    @queue_manager.stub!(:listen)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    listener1.should_receive(:call).with("hi")
    listener2.should_receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "#register_listener should only allow a given listener to be registered once per queue" do
    listener = mock "listener"
    @queue_manager.stub!(:listen)
    @registry.register_listener "FooQ", listener
    @registry.register_listener "FooQ", listener
    listener.should_receive(:call).with("hi").once
    @registry.receive_message("FooQ", mock_message("hi"))
  end


  it "#unregister_listener should only remove the given listener and not close the queue" do
    listener1 = mock "listener 1"
    listener2 = mock "listener 2"
    @queue_manager.stub!(:listen)
    @queue_manager.should_not_receive(:close)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    @registry.unregister_listener listener2
    listener1.should_receive(:call).with("hi")
    @registry.receive_message("FooQ", mock_message("hi"))
  end

  it "should deliver the message to all listeners, but raise the first of any exceptions raised" do
    listener1 = mock "listener 1"
    listener2 = mock "listener 2"
    @queue_manager.stub!(:listen)
    @registry.register_listener "FooQ", listener1
    @registry.register_listener "FooQ", listener2
    listener1.should_receive(:call).with("hi").and_raise "error 1"
    listener2.should_receive(:call).with("hi").and_raise "error 2"
    lambda { @registry.receive_message("FooQ", mock_message("hi")) }.should raise_error("error 1")
  end
end

describe JRuby::Rack::Queues::MessageDispatcher do
  before :each do
    $servlet_context = @servlet_context
    @message = mock "JMS message"
    @listener = mock "listener"
  end

  it "should dispatch to an object that responds to #on_jms_message and provide the JMS message" do
    @listener.should_receive(:on_jms_message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should unmarshal the message if the marshal payload property is set" do
    @message.should_receive(:getBooleanProperty).with(JRuby::Rack::Queues::MARSHAL_PAYLOAD).and_return true
    first = false
    @message.should_receive(:readBytes).twice.and_return do |byte_array|
      if first
        -1
      else
        first = true
        bytes = Marshal.dump("hello").to_java_bytes
        java.lang.System.arraycopy bytes, 0, byte_array, 0, bytes.length
        bytes.length
      end
    end
    @listener.should_receive(:call).with("hello")
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should grab text out of the message if it responds to #getText" do
    @message.stub!(:getBooleanProperty).and_return false
    @message.should_receive(:getText).and_return "hello"
    @listener.should_receive(:call).with("hello")
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should pass the message through otherwise" do
    @message.stub!(:getBooleanProperty).and_return false
    @listener.should_receive(:call).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should dispatch to a listener that responds to #call" do
    @message.stub!(:getBooleanProperty).and_return false
    @listener.should_receive(:call).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  it "should dispatch to a listener that responds to #on_message" do
    @message.stub!(:getBooleanProperty).and_return false
    @listener.should_receive(:on_message).with(@message)
    JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
  end

  class Listener
    def self.message; @@message; end
    def on_message(msg)
      @@message = msg
    end
  end

  it "should instantiate a class and dispatch to it" do
    @message.stub!(:getBooleanProperty).and_return false
    JRuby::Rack::Queues::MessageDispatcher.new(Listener).dispatch(@message)
    Listener.message.should == @message
  end

  it "should log and re-raise any exceptions that are raised during dispatch" do
    @message.stub!(:getBooleanProperty).and_return false
    @listener.should_receive(:on_message).and_raise "something went wrong"
    @servlet_context.should_receive(:log).with(/something went wrong/)
    lambda do
      JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
    end.should raise_error
  end

  it "should raise an exception if it was unable to dispatch to anything" do
    @message.stub!(:getBooleanProperty).and_return false
    lambda do
      JRuby::Rack::Queues::MessageDispatcher.new(@listener).dispatch(@message)
    end.should raise_error
  end
end
