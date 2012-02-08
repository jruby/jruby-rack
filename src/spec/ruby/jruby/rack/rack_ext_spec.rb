#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/rack_ext'

describe Rack::Request do
  
  before :each do
    @servlet_request = mock("servlet_request")
    @servlet_response = mock("servlet_response")
    @rack_request = Rack::Request.new('java.servlet_request' => @servlet_request, 'java.servlet_response' => @servlet_response)
  end

  it "should forward to servlet request dispatcher" do
    @servlet_request.should_receive(:getRequestDispatcher).with('/foo').and_return dispatcher = mock('dispatcher')
    dispatcher.should_receive(:forward).with(@servlet_request, @servlet_response)
    @rack_request.should respond_to(:forward_to)
    @rack_request.forward_to('/foo')
  end

  it "should include servlet response on render" do
    @servlet_request.should_receive(:getRequestDispatcher).with('/foo').
      and_return dispatcher = mock('dispatcher')
    ServletRackIncludedResponse.should_receive(:new).with(@servlet_response).
      and_return included_response = mock('included_response')
    included_response.should_receive(:getOutput).and_return 'foo output'
    dispatcher.should_receive(:include).with(@servlet_request, included_response)
    @rack_request.should respond_to(:render)
    @rack_request.render('/foo').should == 'foo output'
  end
  
end