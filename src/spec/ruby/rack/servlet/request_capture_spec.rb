#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

java_import "org.jruby.rack.servlet.RequestCapture"

describe RequestCapture do
  before do
    @servlet_context = mock("servlet_context")
  end

  # See: https://github.com/jruby/jruby-rack/issues/44
  it "falls back to requestMap when the reader body has been pre-parsed" do
    servlet_request = MockHttpServletRequest.new(@servlet_context)
    servlet_request.content_type = "application/x-www-form-urlencoded"
    servlet_request.parameters = {'foo' => 'bar'}
    servlet_request.content = ''.to_java_bytes

    request_capture = RequestCapture.new(servlet_request)
    request_capture.get_parameter('foo').should == 'bar'
  end
  
  it "reports if input has been accessed" do
    servlet_request = MockHttpServletRequest.new(@servlet_context)
    servlet_request.parameters = {}
    servlet_request.content = '42'.to_java_bytes

    request_capture = RequestCapture.new(servlet_request)
    request_capture.isInputAccessed.should == false
    
    request_capture.getInputStream
    request_capture.isInputAccessed.should == true
    
    request_capture = RequestCapture.new(servlet_request)
    request_capture.getReader
    request_capture.isInputAccessed.should == true
  end
end
