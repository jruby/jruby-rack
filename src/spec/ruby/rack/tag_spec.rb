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
    allow(@result).to receive(:getBody).and_return("Hello World!")

    @application = double("application")
    allow(@application).to receive(:call).and_return @result

    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    allow(@rack_factory).to receive(:getApplication).and_return @application
    allow(@rack_factory).to receive(:finishedWithApplication)

    allow(@servlet_context).to receive(:getAttribute).with('rack.factory').and_return @rack_factory
    allow(@servlet_context).to receive(:getAttribute).with('rack.context').and_return @rack_context
    @servlet_request = double("Servlet Request")
    allow(@servlet_request).to receive(:getContextPath).and_return ""
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
    expect(@rack_factory).to receive(:getApplication).and_return @application
    expect(@rack_factory).to receive(:finishedWithApplication)

    @tag.doEndTag
  end

  it 'should return the application to the pool even when an exception is thrown' do
    expect(@rack_factory).to receive(:getApplication).and_return ExceptionThrower.new
    expect(@rack_factory).to receive(:finishedWithApplication)

    begin
      @tag.doEndTag
    rescue Java::JavaxServletJsp::JspException
      # noop
    end
  end

  it 'should create a request wrapper and invoke the application' do
    expect(@application).to receive(:call).and_return @result
    @tag.doEndTag
  end

  it 'should override the path, query params, and http method of the request' do
    expect(@application).to receive(:call) do |wrapped_request|
      expect(wrapped_request.servlet_path).to eq ""
      expect(wrapped_request.path_info).to eq '/controller/action/id'
      expect(wrapped_request.query_string).to eq 'fruit=apple&horse_before=cart'
      expect(wrapped_request.request_uri).to eq '/controller/action/id?fruit=apple&horse_before=cart'
      expect(wrapped_request.method).to eq 'GET'
      @result
    end

    @tag.doEndTag
  end

  it 'should write the response back to the page' do
    @tag.doEndTag
    expect(@writable.to_s).to eq 'Hello World!'
  end
end
