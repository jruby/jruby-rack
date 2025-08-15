#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe org.jruby.rack.servlet.RequestCapture do

  let(:servlet_request) { MockHttpServletRequest.new(servlet_context) }
  let(:request_capture) do
    org.jruby.rack.servlet.RequestCapture.new(servlet_request)
  end

  # See: https://github.com/jruby/jruby-rack/issues/44
  it "falls back to requestMap when the reader body has been pre-parsed" do
    servlet_request.content_type = "application/x-www-form-urlencoded"
    servlet_request.parameters = { 'foo' => 'bar' }
    servlet_request.content = ''.to_java_bytes

    expect(request_capture.get_parameter('foo')).to eq 'bar'
  end

  it "reports if input-stream has been accessed" do
    servlet_request.parameters = {}
    servlet_request.content = '42'.to_java_bytes

    request_capture = RequestCapture.new(servlet_request)
    expect(request_capture.isInputAccessed).to eq false

    request_capture.getInputStream
    expect(request_capture.isInputAccessed).to eq true
  end

  it "reports if reader has been accessed" do
    servlet_request.parameters = {}
    servlet_request.content = '42'.to_java_bytes

    request_capture = RequestCapture.new(servlet_request)
    expect(request_capture.isInputAccessed).to eq false

    request_capture.getReader
    expect(request_capture.isInputAccessed).to eq true
  end

end
