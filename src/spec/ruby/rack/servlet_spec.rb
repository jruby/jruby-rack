#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.RackServlet, "service" do

  it "should delegate to process" do
    request = jakarta.servlet.http.HttpServletRequest.impl {}
    response = jakarta.servlet.http.HttpServletResponse.impl {}
    dispatcher = double "dispatcher"
    dispatcher.should_receive(:process)
    servlet = org.jruby.rack.RackServlet.new dispatcher, @rack_context
    servlet.service request, response
  end

  it "should destroy dispatcher on destroy" do
    dispatcher = double "dispatcher"
    dispatcher.should_receive(:destroy)
    servlet = org.jruby.rack.RackServlet.new dispatcher, @rack_context
    servlet.destroy
  end

  it "should have default constructor (for servlet container)" do
    lambda { org.jruby.rack.RackServlet.new }.should_not raise_error
  end

end

describe ServletRackContext, "getRealPath" do

  before :each do
    rack_config = org.jruby.rack.servlet.ServletRackConfig.new(@servlet_context)
    @context =  org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
  end

  it "should use getResource when getRealPath returns nil" do
    @servlet_context.stub(:getRealPath).and_return nil
    url = java.net.URL.new("file:///var/tmp/foo.txt")
    @servlet_context.should_receive(:getResource).with("/WEB-INF").and_return url
    @context.getRealPath("/WEB-INF").should == "/var/tmp/foo.txt"
  end

  it "should strip file: prefix for getRealPath" do
    @servlet_context.stub(:getRealPath).and_return nil

    # we're emulating a ServletContext.getResource returning an URL which might
    # differ for different containers - WLS 10 might behave this way from time:
    url = java.net.URL.new 'file', nil, 0, "file:/foo/bar", nil
    # url.path.should == "file:/foo/bar"
    @servlet_context.should_receive(:getResource).with("/bar").and_return url
    @context.getRealPath("/bar").should == "/foo/bar"

    url = java.net.URL.new 'file', nil, 0, "file:///foo/bar", nil
    # url.path.should == "file:///foo/bar"
    @servlet_context.should_receive(:getResource).with("/bar").and_return url
    @context.getRealPath("/bar").should == "/foo/bar"
  end

end
