#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

class ExceptionThrower
  def call(request)
    raise 'Had a problem!'
  end
end

describe org.jruby.rack.RackTag do

  before :each do
    @result = double("Rack Result")
    @result.stub(:getBody).and_return("Hello World!")

    @application = double("application")
    @application.stub(:call).and_return @result

    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    @rack_factory.stub(:getApplication).and_return @application
    @rack_factory.stub(:finishedWithApplication)

    @servlet_context.stub(:getAttribute).with('rack.factory').and_return @rack_factory
    @servlet_context.stub(:getAttribute).with('rack.context').and_return @rack_context
    @servlet_request = double("Servlet Request")
    @servlet_request.stub(:getContextPath).and_return ""
    @servlet_response = double("Servlet Response")

    @writable = org.jruby.rack.fake.FakeJspWriter.new
    @page_context = org.jruby.rack.fake.FakePageContext.new(@servlet_context, @servlet_request, @servlet_response, @writable)

    @tag = org.jruby.rack.RackTag.new
    @tag.setPageContext(@page_context)
    @tag.setPath("/controller/action/id")
    @tag.setParams("fruit=apple&horse_before=cart")
  end

  it 'should be able to construct a new tag' do
    org.jruby.rack.RackTag.new
  end

  it 'should get an application and return it to the pool' do
    @rack_factory.should_receive(:getApplication).and_return @application
    @rack_factory.should_receive(:finishedWithApplication)

    @tag.doEndTag
  end

  it 'should return the application to the pool even when an exception is thrown' do
    @rack_factory.should_receive(:getApplication).and_return ExceptionThrower.new
    @rack_factory.should_receive(:finishedWithApplication)

    begin
      @tag.doEndTag
    rescue Java::JavaxServletJsp::JspException
      #noop
    end
  end

  it 'should create a request wrapper and invoke the application' do
    @application.should_receive(:call).and_return @result
    @tag.doEndTag
  end

  it 'should override the path, query params, and http method of the request' do
    @application.should_receive(:call).and_return do |wrapped_request|
      wrapped_request.servlet_path.should == ""
      wrapped_request.path_info.should == '/controller/action/id'
      wrapped_request.query_string.should == 'fruit=apple&horse_before=cart'
      wrapped_request.request_uri.should == '/controller/action/id?fruit=apple&horse_before=cart'
      wrapped_request.method.should == 'GET'
      @result
    end

    @tag.doEndTag
  end

  it 'should write the response back to the page' do
    @tag.doEndTag
    @writable.to_s.should == 'Hello World!'
  end
end
