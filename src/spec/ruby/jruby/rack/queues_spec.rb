#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/queues'

describe JRuby::Rack::Queues do
  before :each do
    $servlet_context = @servlet_context
  end
  after :each do
    $servlet_context = nil
  end

  it "#with_jms_connection should yield a JMS connection" do
    qm = mock "queue manager"
    @servlet_context.should_receive(:getAttribute).with(org.jruby.rack.jms.QueueContextListener::MGR_KEY).and_return qm
    conn_factory = mock "connection factory"
    qm.should_receive(:getConnectionFactory).and_return conn_factory
    conn = mock "connection"
    conn_factory.should_receive(:createConnection).ordered.and_return conn
    conn.should_receive(:createMessage).ordered
    conn.should_receive(:close).ordered

    JRuby::Rack::Queues.with_jms_connection do |c|
      c.createMessage
    end
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
