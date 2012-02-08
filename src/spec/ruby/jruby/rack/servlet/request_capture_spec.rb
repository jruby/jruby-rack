#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../../..')

java_import "org.jruby.rack.servlet.RequestCapture"
java_import "org.jruby.rack.mock.MockHttpServletRequest"
java_import "org.jruby.rack.servlet.ServletRackConfig"

describe RequestCapture do
  before do
    @servlet_context = mock("servlet_context")
    @rack_config = ServletRackConfig.new(@servlet_context)
  end

  # See: https://github.com/jruby/jruby-rack/issues/44
  it "falls back to requestMap when the reader body has been pre-parsed" do
    servlet_request = MockHttpServletRequest.new(@servlet_context)
    servlet_request.content_type = "application/x-www-form-urlencoded"
    servlet_request.parameters = {'foo' => 'bar'}
    servlet_request.content = ''.to_java_bytes

    request_capture = RequestCapture.new(servlet_request, @rack_config)
    request_capture.get_parameter('foo').should == 'bar'
  end
end
