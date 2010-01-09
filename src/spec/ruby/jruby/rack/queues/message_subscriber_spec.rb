#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'action_controller'
require 'active_record'
require 'jruby/rack/queues'

describe JRuby::Rack::Queues::MessageSubscriber do
  it "should allow publishing to a queue when including the module" do
    subscriber = Object.new
    subscriber.extend JRuby::Rack::Queues::MessageSubscriber
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", subscriber)
    subscriber.subscribes_to("FooQ")
  end
end

describe JRuby::Rack::Queues::ActsAsMessageSubscriber do
  before :each do
    @subscriber = Object.new
    @subscriber.extend JRuby::Rack::Queues::ActsAsMessageSubscriber
  end

  it "should add an acts_as_subscriber when included" do
    @subscriber.respond_to?(:acts_as_subscriber).should be_true
  end

  it "should include MessageSubscriber when acts_as_subscriber is called" do
    @subscriber.acts_as_subscriber
    @subscriber.respond_to?(:subscribes_to).should be_true
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", @subscriber)
    @subscriber.subscribes_to("FooQ")
  end
end

describe ActiveRecord::Base do
  before :each do
    @klass = Class.new(ActiveRecord::Base)
  end

  it "should respond to acts_as_subscriber" do
    @klass.should respond_to(:acts_as_subscriber)
  end

  it "should respond to subscribe_to when acts_as_subscriber is called." do
    @klass.should_not respond_to(:subscribes_to)
    @klass.acts_as_subscriber
    @klass.should respond_to(:subscribes_to)
  end
end

describe ActionController::Base do
  before :each do
    @klass = Class.new(ActionController::Base)
  end

  it "should respond to acts_as_subscriber" do
    @klass.should respond_to(:acts_as_subscriber)
  end

  it "should have a subscribes_to method when acts_as_subscriber is called." do
    @klass.should_not respond_to(:subscribes_to)
    @klass.acts_as_subscriber
    @klass.should respond_to(:subscribes_to)
  end
end

