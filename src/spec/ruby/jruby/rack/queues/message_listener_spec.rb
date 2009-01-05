#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'jruby/rack/queues/message_listener'

describe JRuby::Rack::Queues::MessageListener do
  it "should listen to a queue" do
    klass = Class.new(JRuby::Rack::Queues::MessageListener)
    JRuby::Rack::Queues::Registry.should_receive(:register_listener).with("FooQ", klass)
    klass.listen_to("FooQ")
  end

  it "should raise if #on_message is not implemented in the subclass" do
    klass = Class.new(JRuby::Rack::Queues::MessageListener)
    lambda { klass.new.on_message }.should raise_error
  end
end
