#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'jruby/rack/queues/message_subscriber'

describe JRuby::Rack::Queues::MessageSubscriber do
  it "should allow publishing to a queue when including the module" do
    subscriber = Object.new
    subscriber.extend JRuby::Rack::Queues::MessageSubscriber
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", subscriber)
    subscriber.subscribes_to("FooQ")
  end
end

describe JRuby::Rack::Queues::ActAsMessageSubscriber do
  
  before :each do
    @subscriber = Object.new
    @subscriber.extend JRuby::Rack::Queues::ActAsMessageSubscriber
  end
  
  it "should add an act_as_subscriber when included" do
    @subscriber.respond_to?(:act_as_subscriber).should be_true
  end
  
  it "should include MessageSubscriber when act_as_subscriber is called" do
    @subscriber.act_as_subscriber
    @subscriber.respond_to?(:subscribes_to).should be_true
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", @subscriber)
    @subscriber.subscribes_to("FooQ")
  end
end

describe ActiveRecord::Base do
  before :each do
    @model = ActiveRecord::Base.new
  end

  it "should respond to act_as_subscriber" do
    @model.respond_to?(:act_as_subscriber).should be_true
  end

  it "should respond to subscribe_to when act_as_subscriber is called." do
    @model.respond_to?(:subscribes_to).should be_false
    @model.act_as_subscriber
    @model.respond_to?(:subscribes_to).should be_true
  end
end

describe ActionController::Base do
  before :each do
    @controller = ActionController::Base.new
  end
  
  it "should respond to act_as_subscriber" do
    @controller.respond_to?(:act_as_subscriber).should be_true
  end

  it "should have a subscribes_to method when act_as_subscriber is called." do
    @controller.respond_to?(:subscribes_to).should be_false
    @controller.act_as_subscriber
    @controller.respond_to?(:subscribes_to).should be_true
  end
end

