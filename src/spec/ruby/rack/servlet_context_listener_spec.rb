#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.RackApplicationFactory

describe RackServletContextListener do
  before(:each) do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context_event = javax.servlet.ServletContextEvent.new @servlet_context
    @factory = mock "application factory"
    @listener = RackServletContextListener.new @factory
  end

  describe "contextInitialized" do
    it "should create a Rack application factory and store it in the context" do
      @servlet_context.should_receive(:setAttribute).with(RackServletContextListener::FACTORY_KEY, @factory)
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
        RackServletContextListener::FACTORY_KEY).and_return @factory
      @servlet_context.should_receive(:removeAttribute).with(
        RackServletContextListener::FACTORY_KEY)
      @factory.stub!(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end

    it "should destroy it" do
      @servlet_context.should_receive(:getAttribute).with(
        RackServletContextListener::FACTORY_KEY).and_return @factory
      @servlet_context.stub!(:removeAttribute)
      @factory.should_receive(:destroy)
      @listener.contextDestroyed @servlet_context_event
    end

    it "should do nothing if no application is found in the context" do
      @servlet_context.should_receive(:getAttribute).with(
        RackServletContextListener::FACTORY_KEY).and_return nil
      @listener.contextDestroyed @servlet_context_event
    end
  end
end
