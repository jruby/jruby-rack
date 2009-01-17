#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'action_controller'
require 'active_record'
require 'jruby/rack/queues'

describe JRuby::Rack::Queues::MessagePublisher do
  it "should delegate #publish_message to JRuby::Rack::Queues::Registry.publish_message" do
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessagePublisher
    obj.publish_message("FooQ", "hello")
  end

  it "should allow setting up a default queue name with MessagePublisher::To()" do
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("FooQ", "hello").ordered
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("BarQ", "hello").ordered
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessagePublisher::To("FooQ")
    obj.publish_message("hello")
    obj.publish_message("BarQ", "hello")
  end

  it "should allow setting up a default queue name with #default_destination" do
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessagePublisher
    def obj.default_destination
      "FooQ"
    end
    obj.publish_message("hello")
  end

  it "should ignore unnecessary extra arguments" do
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("FooQ", "hello")
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessagePublisher
    obj.publish_message("FooQ", "hello", 1, 2, 3)
  end

  it "should allow omitting the message argument and specifying a block" do
    message = mock "message"
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("FooQ").ordered.and_yield message
    JRuby::Rack::Queues::Registry.should_receive(:publish_message).with("BarQ").ordered.and_yield message
    obj = Object.new
    obj.extend JRuby::Rack::Queues::MessagePublisher::To("FooQ")
    obj.publish_message do |msg|
      msg.should == message
    end
    obj.publish_message "BarQ" do |msg|
      msg.should == message
    end
  end
end

describe JRuby::Rack::Queues::ActsAsMessagePublisher, "in controllers" do
  before :each do
    @controller = Object.new
    @controller.extend JRuby::Rack::Queues::ActsAsMessagePublisher
  end

  it "should add an acts_as_publisher method" do
    @controller.respond_to?(:acts_as_publisher).should be_true
  end

  it "should add a publish_message method to the controllers" do
    @controller.acts_as_publisher
    @controller.respond_to?(:publish_message).should be_true
    @controller.respond_to?(:default_destination).should be_false
  end

  it "should setup a default destination when called with a parameter" do
    @controller.acts_as_publisher "FooQ"
    @controller.respond_to?(:publish_message).should be_true
    @controller.respond_to?(:default_destination).should be_true
    @controller.default_destination.should == "FooQ"
  end
end

describe ActiveRecord::Base do
  before :each do
    @model = ActiveRecord::Base.new
  end

  it "should respond to acts_as_publisher" do
    @model.respond_to?(:acts_as_publisher).should be_true
  end

  it "should have a publish_message method when acts_as_publisher is called." do
    @model.respond_to?(:publish_message).should be_false
    @model.acts_as_publisher
    @model.respond_to?(:publish_message).should be_true
    @model.respond_to?(:default_destination).should be_false
  end

  it "should have a publish_message and default_destination when acts_as_publisher is called with a queue name." do
    @model.respond_to?(:publish_message).should be_false
    @model.respond_to?(:default_destination).should be_false
    @model.acts_as_publisher "FooQ"
    @model.respond_to?(:publish_message).should be_true
    @model.respond_to?(:default_destination).should be_true
    @model.default_destination.should == "FooQ"
  end
end

describe ActionController::Base do
  before :each do
    @controller = ActionController::Base.new
  end

  it "should respond to acts_as_publisher" do
    @controller.respond_to?(:acts_as_publisher).should be_true
  end

  it "should respond to publish_message when acts_as_publisher is called." do
    @controller.respond_to?(:publish_message).should be_false
    @controller.acts_as_publisher
    @controller.respond_to?(:publish_message).should be_true
    @controller.respond_to?(:default_destination).should be_false
  end

  it "should respond to default_destination when acts_as_publisher is called with a queue name." do
    @controller.respond_to?(:publish_message).should be_false
    @controller.respond_to?(:default_destination).should be_false
    @controller.acts_as_publisher "FooQ"
    @controller.respond_to?(:publish_message).should be_true
    @controller.respond_to?(:default_destination).should be_true
    @controller.default_destination.should == "FooQ"
  end
end
