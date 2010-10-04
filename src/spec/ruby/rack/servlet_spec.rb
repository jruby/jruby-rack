#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.RackServlet
import org.jruby.rack.servlet.ServletRackContext

describe RackServlet, "service" do
  it "should delegate to process" do
    request = javax.servlet.http.HttpServletRequest.impl {}
    response = javax.servlet.http.HttpServletResponse.impl {}
    dispatcher = mock "dispatcher"
    dispatcher.should_receive(:process).with(request, response)
    @servlet = RackServlet.new dispatcher
    @servlet.service request, response
  end
end

describe ServletRackContext, "getRealPath" do
  before :each do
    @context = ServletRackContext.new(@servlet_context)
  end

  it "should use getResource when getRealPath returns nil" do
    @servlet_context.stub!(:getRealPath).and_return nil
    url = java.net.URL.new("file:///var/tmp/foo.txt")
    @servlet_context.should_receive(:getResource).with("/WEB-INF").and_return url
    @context.getRealPath("/WEB-INF").should == "/var/tmp/foo.txt"
  end
end
