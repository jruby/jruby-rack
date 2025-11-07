#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/rack_ext'

describe JRuby::Rack::RackExt do
  before :each do
    @servlet_request = double("servlet_request")
    @servlet_response = double("servlet_response")
    @rack_request = Rack::Request.new(
      'java.servlet_request' => @servlet_request,
      'java.servlet_response' => @servlet_response
    )
  end

  it "should forward to servlet request dispatcher" do
    expect(@servlet_request).to receive(:getRequestDispatcher).
      with('/foo').and_return dispatcher = double('dispatcher')
    expect(dispatcher).to receive(:forward).
      with(@servlet_request, @servlet_response)
    expect(@rack_request).to respond_to(:forward_to)
    @rack_request.forward_to('/foo')
  end

  it "should include servlet response on render" do
    expect(@servlet_request).to receive(:getRequestDispatcher).
      with('/foo').and_return dispatcher = double('dispatcher')
    expect(org.jruby.rack.servlet.ServletRackIncludedResponse).to receive(:new).
      with(@servlet_response).and_return included_response = double('included_response')
    expect(included_response).to receive(:getOutput).and_return 'foo output'
    expect(dispatcher).to receive(:include).with(@servlet_request, included_response)
    expect(@rack_request).to respond_to(:render)
    expect(@rack_request.render('/foo')).to eq 'foo output'
  end
end
