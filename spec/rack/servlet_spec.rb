#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.RackServlet

describe RackServlet do
  before :each do
    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    @servlet_context.should_receive(:getAttribute).with("rack.factory").and_return @rack_factory
    @servlet = RackServlet.new
    @servlet.init(@servlet_config)
  end

  describe "service" do
    it "should delegate to process" do
      request = javax.servlet.http.HttpServletRequest.impl {}
      response = javax.servlet.http.HttpServletResponse.impl {}
      application = mock("application")
      result = mock("rack result")
      result.stub!(:writeStatus)
      result.stub!(:writeHeaders)
      result.stub!(:writeBody)
      @rack_factory.stub!(:getApplication).and_return application
      @rack_factory.stub!(:finishedWithApplication)
      application.stub!(:call).and_return result

      @servlet.service request, response
    end
  end

  describe "process" do
    it "should retrieve a RackApplication and call it" do
      application = mock("application")
      request = mock("request")
      response = mock("response")
      result = mock("rack result")

      @rack_factory.should_receive(:getApplication).and_return(application)
      @rack_factory.should_receive(:finishedWithApplication).with(application)
      application.should_receive(:call).with(request).and_return result
      result.should_receive(:writeStatus)
      result.should_receive(:writeHeaders)
      result.should_receive(:writeBody)

      @servlet.process(request, response)
    end

    it "should let the error application handle the error if the application could not be initialized" do
      @rack_factory.stub!(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
      error_app = mock "error application"
      @rack_factory.should_receive(:getErrorApplication).and_return error_app
      req, res = mock("request"), mock("response")
      req.should_receive(:setAttribute).with(RackServlet::EXCEPTION, anything())
      res.should_receive(:isCommitted).and_return false
      res.should_receive(:reset)
      result = mock "result"
      error_app.should_receive(:call).with(req).and_return result
      result.should_receive(:writeStatus)
      result.should_receive(:writeHeaders)
      result.should_receive(:writeBody)
      @servlet.process(req, res)
    end

    it "should stop processing on error if the response is already committed" do
      application = mock("application")
      @rack_factory.stub!(:getApplication).and_return application
      @rack_factory.should_receive(:finishedWithApplication).with application
      application.stub!(:call).and_raise "some error"
      req, res = mock("request"), mock("response")
      res.stub!(:isCommitted).and_return true
      @servlet.process(req, res)
    end

    it "should send a 500 error if the error application can't successfully handle the error" do
      @rack_factory.stub!(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
      error_app = mock "error application"
      @rack_factory.should_receive(:getErrorApplication).and_return error_app
      req, res = mock("request"), mock("response")
      req.stub!(:setAttribute)
      res.stub!(:isCommitted).and_return false
      res.stub!(:reset)
      result = mock "result"
      error_app.should_receive(:call).with(req).and_raise "some error"
      res.should_receive(:sendError).with(500)
      @servlet.process(req, res)
    end
  end
end
