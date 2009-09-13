#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.servlet.DefaultServletDispatcher

describe DefaultServletDispatcher do
  before :each do
    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    @rack_context.should_receive(:getRackFactory).and_return @rack_factory
    @dispatcher = DefaultServletDispatcher.new @rack_context
  end

  describe "process" do
    it "should retrieve a RackApplication and call it" do
      application = mock("application")
      request = mock("request")
      response = mock("response")
      rack_response = mock("rack response")

      @rack_factory.should_receive(:getApplication).and_return(application)
      @rack_factory.should_receive(:finishedWithApplication).with(application)
      application.should_receive(:call).and_return rack_response
      rack_response.should_receive(:respond)

      @dispatcher.process(request, response)
    end

    it "should let the error application handle the error if the application could not be initialized" do
      @rack_factory.stub!(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
      error_app = mock "error application"
      @rack_factory.should_receive(:getErrorApplication).and_return error_app
      req, res = mock("request"), mock("response")
      req.should_receive(:setAttribute).with(org.jruby.rack.RackEnvironment::EXCEPTION, anything())
      res.should_receive(:isCommitted).and_return false
      res.should_receive(:reset)
      rack_response = mock "rack response"
      error_app.should_receive(:call).and_return rack_response
      rack_response.should_receive(:respond)
      @dispatcher.process(req, res)
    end

    it "should stop processing on error if the response is already committed" do
      application = mock("application")
      @rack_factory.stub!(:getApplication).and_return application
      @rack_factory.should_receive(:finishedWithApplication).with application
      application.stub!(:call).and_raise "some error"
      req, res = mock("request"), mock("response")
      res.stub!(:isCommitted).and_return true
      @dispatcher.process(req, res)
    end

    it "should send a 500 error if the error application can't successfully handle the error" do
      @rack_factory.stub!(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
      error_app = mock "error application"
      @rack_factory.should_receive(:getErrorApplication).and_return error_app
      req, res = mock("request"), mock("response")
      req.stub!(:setAttribute)
      res.stub!(:isCommitted).and_return false
      res.stub!(:reset)
      error_app.should_receive(:call).and_raise "some error"
      res.should_receive(:sendError).with(500)
      @dispatcher.process(req, res)
    end
  end
end
