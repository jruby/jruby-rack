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
    @subscriber.respond_to? :act_as_subscriber
  end
  
  it "should include MessageSubscriber when act_as_subscriber is called" do
    @subscriber.act_as_subscriber
    @subscriber.respond_to? :subscribes_to
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", @subscriber)
    @subscriber.subscribes_to("FooQ")
  end
end