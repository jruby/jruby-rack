#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack/servlet_ext'

describe Java::JavaxServletHttp::HttpServletRequest do
  before :each do
    @request = Java::JavaxServletHttp::HttpServletRequest.impl {}
  end

  it "should allow #[] to access request attributes" do
    @request.should_receive(:getAttribute).with("HA!").and_return "NYAH!"
    @request["HA!"].should == "NYAH!"
  end

  it "should stringify the key, allowing symbols to be used as keys" do
    @request.should_receive(:getAttribute).with("foo").and_return "bar"
    @request[:foo].should == "bar"
  end

  it "should allow #[]= to set request attributes" do
    @request.should_receive(:setAttribute).with("HA!", "NYAH!")
    @request["HA!"] = "NYAH!"
  end

  it "should give an array of keys from getAttributeNames" do
    names = %w(a b c)
    @request.should_receive(:getAttributeNames).and_return names
    @request.keys.should == names
  end
end

describe Java::JavaxServletHttp::HttpSession do
  before :each do
    @session = Java::JavaxServletHttp::HttpSession.impl {}
  end

  it "should allow #[] to access session attributes" do
    @session.should_receive(:getAttribute).with("HA!").and_return "NYAH!"
    @session["HA!"].should == "NYAH!"
  end

  it "should stringify the key, allowing symbols to be used as keys" do
    @session.should_receive(:getAttribute).with("foo").and_return "bar"
    @session[:foo].should == "bar"
  end

  it "should allow #[]= to set session attributes" do
    @session.should_receive(:setAttribute).with("HA!", "NYAH!")
    @session["HA!"] = "NYAH!"
  end

  it "should give an array of keys from getAttributeNames" do
    names = %w(a b c)
    @session.should_receive(:getAttributeNames).and_return names
    @session.keys.should == names
  end
end
