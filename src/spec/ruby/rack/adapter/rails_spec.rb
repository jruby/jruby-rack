#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'vendor/rack'
require 'rack/adapter/rails'
require 'rack/adapter/rails_cgi'

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

  it "should not look for static files if 'jruby.rack.dynamic.requests.only' is present in the environment" do
    @rails.should_receive(:serve_rails).and_return [200, {}, ""]
    @env["jruby.rack.dynamic.requests.only"] = true
    @rails.call(@env).should == [200, {}, ""]
  end
end

describe Rack::Adapter::RailsCgi::CGIWrapper, "#header" do
  before :each do
    @request, @response = mock("request"), mock("response")
    @request.stub!(:env).and_return({"REQUEST_METHOD" => "GET"})
    @request.stub!(:body).and_return ""
    @wrapper = Rack::Adapter::RailsCgi::CGIWrapper.new(@request, @response)
  end

  it "should set the Content-Type from the 'type' key in the options" do
    options = {'type' => 'text/xml'}
    @response.should_receive(:[]=).with('Content-Type', options['type'])
    @wrapper.header(options)
  end

  it "should set the Content-Length if present" do
    options = {'Content-Length' => 10}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_receive(:[]=).with('Content-Length', '10')
    @wrapper.header(options)
  end

  it "should set the Content-Language and Expires from language and expires options" do
    options = {'language' => 'en', 'expires' => 'soon'}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_receive(:[]=).with('Content-Language', 'en')
    @response.should_receive(:[]=).with('Expires', 'soon')
    @wrapper.header(options)
  end

  it "should set the status from the status option" do
    options = {'Status' => '200'}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_receive(:status=).with('200')
    @wrapper.header(options)
  end

  it "should set cookies as an array of strings in the Set-Cookie header" do
    options = {'cookie' => %w(a b c d)}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_receive(:[]=).with('Set-Cookie', options['cookie'])
    @wrapper.header(options)
  end

  it "should not set the Set-Cookie header if the cookie option is an empty array" do
    options = {'cookie' => []}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_not_receive(:[]=).with('Set-Cookie', anything())
    @wrapper.header(options)
  end

  it "should pass any other options through as headers" do
    options = {'blah' => '200', 'bza' => 'hey'}
    @response.should_receive(:[]=).with('Content-Type', 'text/html')
    @response.should_receive(:[]=).with('blah', '200')
    @response.should_receive(:[]=).with('bza', 'hey')
    @wrapper.header(options)
  end
end
