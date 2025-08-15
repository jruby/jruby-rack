#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../../spec_helper', File.dirname(__FILE__))
require 'jruby/rack/queues/activemq'

describe JRuby::Rack::Queues::ActiveMQ do
  before :each do
    @amq = JRuby::Rack::Queues::ActiveMQ.new
  end

  def jndi_properties
    JRuby::Rack::Queues::LocalContext.init_parameters["jms.jndi.properties"]
  end

  it "configure should start the queue manager and register an at_exit handler to stop it" do
    expect(JRuby::Rack::Queues::Registry).to receive(:start_queue_manager).ordered
    expect(JRuby::Rack::Queues::Registry).to receive(:stop_queue_manager).ordered
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
    expect(jndi_properties).to match /url\s*=\s*tcp:\/\/localhost:61616/
  end

  it "should put the username and password in the JNDI properties if present" do
    @amq.register_jndi_properties
    expect(jndi_properties).not_to match /java\.naming\.security\.principal/
    expect(jndi_properties).not_to match /java\.naming\.security\.credentials/
    @amq.username = 'foo'
    @amq.password = 'bar'
    @amq.register_jndi_properties
    expect(jndi_properties).to match /principal\s*=\s*foo/
    expect(jndi_properties).to match /credentials\s*=\s*bar/
  end

  it "should add one queue entry for each named queue" do
    @amq.queues << "foo" << "bar"
    @amq.register_jndi_properties
    expect(jndi_properties).to match /queue\.foo\s*=\s*foo/
    expect(jndi_properties).to match /queue\.bar\s*=\s*bar/
  end

  it "should add one topic entry for each named topic" do
    @amq.topics << "foo" << "bar"
    @amq.register_jndi_properties
    expect(jndi_properties).to match /topic\.foo\s*=\s*foo/
    expect(jndi_properties).to match /topic\.bar\s*=\s*bar/
  end
end
