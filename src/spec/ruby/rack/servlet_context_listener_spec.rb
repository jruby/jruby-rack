#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

java_import org.jruby.rack.RackApplicationFactory

describe RackServletContextListener do
  before(:each) do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context_event = javax.servlet.ServletContextEvent.new @servlet_context
    @factory = mock "application factory"
    # @listener = RackServletContextListener.new(@factory) :
    constructor = RackServletContextListener.java_class.to_java.
      getDeclaredConstructor(RackApplicationFactory.java_class)
    constructor.accessible = true
    @listener = constructor.newInstance(@factory.to_java(RackApplicationFactory))
  end

  describe "contextInitialized" do
    it "should create a Rack application factory and store it in the context" do
      @servlet_context.should_receive(:setAttribute).with(RackApplicationFactory::FACTORY, @factory)
      @servlet_context.should_receive(:setAttribute).with(RackApplicationFactory::RACK_CONTEXT, anything())
      @factory.stub!(:init)
      @listener.contextInitialized @servlet_context_event
    end

    it "should initialize it" do
      @servlet_context.stub!(:setAttribute)
      @factory.should_receive(:init)
      @listener.contextInitialized @servlet_context_event
    end

    it "should log an error if initialize failed" do
      @servlet_context.stub!(:setAttribute)
      @factory.should_receive(:init).and_raise "help"
      @servlet_context.should_receive(:log).with(/initialization failed/, anything())
      @listener.contextInitialized @servlet_context_event
    end
  end

  describe "contextDestroyed" do
    it "should remove the application factory from the servlet context" do
      @servlet_context.should_receive(:getAttribute).with(
        RackApplicationFactory::FACTORY).and_return @factory
      @servlet_context.should_receive(:removeAttribute).with(
        RackApplicationFactory::FACTORY)
      @servlet_context.should_receive(:removeAttribute).with(
        RackApplicationFactory::RACK_CONTEXT)
      @factory.stub!(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end

    it "should destroy it" do
      @servlet_context.should_receive(:getAttribute).with(
        RackApplicationFactory::FACTORY).and_return @factory
      @servlet_context.stub!(:removeAttribute)
      @factory.should_receive(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end

    it "should do nothing if no application is found in the context" do
      @servlet_context.should_receive(:getAttribute).with(
        RackApplicationFactory::FACTORY).and_return nil
      @listener.contextDestroyed @servlet_context_event
    end
  end
  
  it "should have default constructor (for servlet container)" do
    lambda { RackServletContextListener.new }.should_not raise_error
  end
  
  it "pools runtimes when max > 1" do
    @rack_config.stub!(:getMaximumRuntimes).and_return(2)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end
  
  it "does not pool when max = 1" do
    @rack_config.stub!(:getMaximumRuntimes).and_return(1)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end
  
  it "does not pool by default" do
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end
  
end

java_import org.jruby.rack.rails.RailsServletContextListener

describe RailsServletContextListener do

  it "should have default constructor (for servlet container)" do
    lambda { RailsServletContextListener.new }.should_not raise_error
  end

  it "pools runtimes by default" do
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end
  
  it "pools runtimes when max > 1" do
    @rack_config.stub!(:getMaximumRuntimes).and_return(3)
    @rack_config.stub!(:isSerialInitialization).and_return(true)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SerialPoolingRackApplicationFactory)
  end
  
  it "does not pool when max = 1" do
    @rack_config.stub!(:getMaximumRuntimes).and_return(1)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end
  
end
