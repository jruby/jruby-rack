#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.RackServlet
import org.jruby.rack.servlet.DefaultServletRackContext
import org.jruby.rack.servlet.ServletRackConfig

describe RackServlet, "service" do
  
  it "should delegate to process" do
    request = javax.servlet.http.HttpServletRequest.impl {}
    response = javax.servlet.http.HttpServletResponse.impl {}
    dispatcher = mock "dispatcher"
    dispatcher.should_receive(:process)
    @servlet = RackServlet.new dispatcher
    @servlet.service request, response
  end
  
  it "should have default constructor (for servlet container)" do
    lambda { RackServlet.new }.should_not raise_error
  end
  
end

describe ServletRackContext, "getRealPath" do
  before :each do
    @context = DefaultServletRackContext.new(ServletRackConfig.new(@servlet_context))
  end

  it "should use getResource when getRealPath returns nil" do
    @servlet_context.stub!(:getRealPath).and_return nil
    url = java.net.URL.new("file:///var/tmp/foo.txt")
    @servlet_context.should_receive(:getResource).with("/WEB-INF").and_return url
    @context.getRealPath("/WEB-INF").should == "/var/tmp/foo.txt"
  end
end
