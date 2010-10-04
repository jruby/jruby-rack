#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack/queues/activemq'

describe JRuby::Rack::Queues::ActiveMQ do
  before :each do
    @amq = JRuby::Rack::Queues::ActiveMQ.new
  end

  def jndi_properties
    JRuby::Rack::Queues::LocalContext.init_parameters["jms.jndi.properties"]
  end

  it "configure should start the queue manager and register an at_exit handler to stop it" do
    JRuby::Rack::Queues::Registry.should_receive(:start_queue_manager).ordered
    JRuby::Rack::Queues::Registry.should_receive(:stop_queue_manager).ordered
    active_mq = JRuby::Rack::Queues::ActiveMQ
    def active_mq.at_exit(&block)
      @exit_block = block
    end
    def active_mq.exit_block
      @exit_block
    end
    active_mq.configure do |amq|
      amq
    end
    active_mq.exit_block.call
  end

  it "should put the specified URL in the JNDI properties" do
    @amq.url = "tcp://localhost:61616"
    @amq.register_jndi_properties
    jndi_properties.should =~ /url\s*=\s*tcp:\/\/localhost:61616/
  end

  it "should put the username and password in the JNDI properties if present" do
    @amq.register_jndi_properties
    jndi_properties.should_not =~ /java\.naming\.security\.principal/
    jndi_properties.should_not =~ /java\.naming\.security\.credentials/
    @amq.username = 'foo'
    @amq.password = 'bar'
    @amq.register_jndi_properties
    jndi_properties.should =~ /principal\s*=\s*foo/
    jndi_properties.should =~ /credentials\s*=\s*bar/
  end

  it "should add one queue entry for each named queue" do
    @amq.queues << "foo" << "bar"
    @amq.register_jndi_properties
    jndi_properties.should =~ /queue\.foo\s*=\s*foo/
    jndi_properties.should =~ /queue\.bar\s*=\s*bar/
  end

  it "should add one topic entry for each named topic" do
    @amq.topics << "foo" << "bar"
    @amq.register_jndi_properties
    jndi_properties.should =~ /topic\.foo\s*=\s*foo/
    jndi_properties.should =~ /topic\.bar\s*=\s*bar/
  end
end
