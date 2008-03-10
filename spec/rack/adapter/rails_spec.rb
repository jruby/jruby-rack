#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack'
require 'rack/adapter/rails'

module ActionController
  class Base; end
end

describe Rack::Adapter::Rails do
  before :each do
    ActionController::Base.stub!(:page_cache_extension).and_return ".html"
    @rails = Rack::Adapter::Rails.new
    class << @rails; public :instance_variable_set; end
    @file_server = mock "file server"
    @file_server.stub!(:root).and_return "/tmp/root/public"
    @rails.instance_variable_set "@file_server", @file_server
    @env = {}
  end

  it "should serve a static file first if it exists" do
    File.should_receive(:file?).with("/tmp/root/public/index.html").and_return true
    File.should_receive(:readable?).with("/tmp/root/public/index.html").and_return true
    @file_server.should_receive(:call).and_return [200, {}, ""]
    
    @env["PATH_INFO"] = "index.html"
    @rails.call(@env).should == [200, {}, ""]
  end

  it "should serve a static file with the page cache extension second if it exists" do
    File.should_receive(:file?).with("/tmp/root/public/index").and_return false
    File.should_receive(:file?).with("/tmp/root/public/index.html").and_return true
    File.should_receive(:readable?).with("/tmp/root/public/index.html").and_return true
    @file_server.should_receive(:call).and_return [200, {}, ""]
    
    @env["PATH_INFO"] = "index"
    @rails.call(@env).should == [200, {}, ""]
    @env["PATH_INFO"].should == "index.html"
  end

  it "should serve Rails last if no static files are found for the request" do
    File.should_receive(:file?).with("/tmp/root/public/index").and_return false
    File.should_receive(:file?).with("/tmp/root/public/index.html").and_return false
    @rails.should_receive(:serve_rails).and_return [200, {}, ""]
    
    @env["PATH_INFO"] = "index"
    @rails.call(@env).should == [200, {}, ""]
  end

  it "should not look for static files if 'rack.dynamic.requests.only' is present in the environment" do
    @rails.should_receive(:serve_rails).and_return [200, {}, ""]
    @env["rack.dynamic.requests.only"] = true
    @rails.call(@env).should == [200, {}, ""]
  end
end