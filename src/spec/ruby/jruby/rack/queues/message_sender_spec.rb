#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'jruby/rack/queues/message_sender'

describe JRuby::Rack::Queues::MessageSender do
  it "should delegate #send_message to JRuby::Rack::Queues::Registry.send_message" do
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessageSender
    obj.send_message("FooQ", "hello")
  end

  it "should allow setting up a default queue name with MessageSender::To()" do
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("FooQ", "hello").ordered
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("BarQ", "hello").ordered
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessageSender::To("FooQ")
    obj.send_message("hello")
    obj.send_message("BarQ", "hello")
  end

  it "should allow setting up a default queue name with #default_destination" do
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessageSender
    def obj.default_destination
      "FooQ"
    end
    obj.send_message("hello")
  end

  it "should ignore unnecessary extra arguments" do
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessageSender
    obj.send_message("FooQ", "hello", 1, 2, 3)
  end

  it "should allow omitting the message argument and specifying a block" do
    message = mock "message"
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("FooQ").ordered.and_yield message
    JRuby::Rack::Queues::Registry.should_receive(:send_message).with("BarQ").ordered.and_yield message
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessageSender::To("FooQ")
    obj.send_message do |msg|
      msg.should == message
    end
    obj.send_message "BarQ" do |msg|
      msg.should == message
    end
  end
end
