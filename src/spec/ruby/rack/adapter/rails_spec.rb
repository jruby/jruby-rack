#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))

require 'action_controller' if defined? Rails

# if defined? ActionController::Base.session_options # :rails23
#  # avoid ArgumentError with real 2.3 (default) middleware-stack :
#  # A key is required to write a cookie containing the session data.
#  # Use config.action_controller.session = ... in config/environment.rb
#  ActionController::Base.session_options.update({
#    :key => "_testapp_session", :secret => "some secret phrase" * 42
#  })
# else # :stub
#  module ActionController
#    class Base; end
#  end
# end

require 'rack/adapter/rails'

describe 'Rack::Adapter::Rails' do

  before :all do
    # avoid ArgumentError with real 2.3 (default) middleware-stack :
    # A key is required to write a cookie containing the session data.
    # Use config.action_controller.session = ... in config/environment.rb
    ActionController::Base.session_options.update(
      {
        :key => "_testapp_session", :secret => "some secret phrase" * 42
      })
  end

  before :each do
    allow(ActionController::Base).to receive(:page_cache_extension).and_return ".html"
    @rails = Rack::Adapter::Rails.new

    class << @rails
      public :instance_variable_set;
    end

    @file_server = double "file server"
    allow(@file_server).to receive(:root).and_return "/tmp/root/public"
    @rails.instance_variable_set "@file_server", @file_server
    @env = {}
  end

  it "should serve a static file first if it exists" do
    expect(File).to receive(:file?).with("/tmp/root/public/index.html").and_return true
    expect(File).to receive(:readable?).with("/tmp/root/public/index.html").and_return true
    expect(@file_server).to receive(:call).and_return [200, {}, ""]

    @env["PATH_INFO"] = "index.html"
    expect(@rails.call(@env)).to eq [200, {}, ""]
  end

  it "should serve a static file with the page cache extension second if it exists" do
    expect(File).to receive(:file?).with("/tmp/root/public/index").and_return false
    expect(File).to receive(:file?).with("/tmp/root/public/index.html").and_return true
    expect(File).to receive(:readable?).with("/tmp/root/public/index.html").and_return true
    expect(@file_server).to receive(:call).and_return [200, {}, ""]

    @env["PATH_INFO"] = "index"
    expect(@rails.call(@env)).to eq [200, {}, ""]
    expect(@env["PATH_INFO"]).to eq "index.html"
  end

  it "should serve Rails last if no static files are found for the request" do
    expect(File).to receive(:file?).with("/tmp/root/public/index").and_return false
    expect(File).to receive(:file?).with("/tmp/root/public/index.html").and_return false
    expect(@rails).to receive(:serve_rails).and_return [200, {}, ""]

    @env["PATH_INFO"] = "index"
    expect(@rails.call(@env)).to eq [200, {}, ""]
  end

  it "should not look for static files if 'jruby.rack.dynamic.requests.only' is present in the environment" do
    expect(@rails).to receive(:serve_rails).and_return [200, {}, ""]
    @env["jruby.rack.dynamic.requests.only"] = true
    expect(@rails.call(@env)).to eq [200, {}, ""]
  end

end if defined? ActionController::Base.session_options # :rails23

require 'rack/adapter/rails_cgi'

describe 'Rack::Adapter::RailsCgi::CGIWrapper', "#header" do

  before :each do
    @request, @response = double("request"), double("response")
    allow(@request).to receive(:env).and_return({ "REQUEST_METHOD" => "GET" })
    allow(@request).to receive(:body).and_return ""
    @wrapper = Rack::Adapter::RailsCgi::CGIWrapper.new(@request, @response)
  end

  it "should set the Content-Type from the 'type' key in the options" do
    options = { 'type' => 'text/xml' }
    expect(@response).to receive(:[]=).with('Content-Type', options['type'])
    @wrapper.header(options)
  end

  it "should set the Content-Length if present" do
    options = { 'Content-Length' => 10 }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).to receive(:[]=).with('Content-Length', '10')
    @wrapper.header(options)
  end

  it "should set the Content-Language and Expires from language and expires options" do
    options = { 'language' => 'en', 'expires' => 'soon' }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).to receive(:[]=).with('Content-Language', 'en')
    expect(@response).to receive(:[]=).with('Expires', 'soon')
    @wrapper.header(options)
  end

  it "should set the status from the status option" do
    options = { 'Status' => '200' }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).to receive(:status=).with('200')
    @wrapper.header(options)
  end

  it "should set cookies as an array of strings in the Set-Cookie header" do
    options = { 'cookie' => %w(a b c d) }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).to receive(:[]=).with('Set-Cookie', options['cookie'])
    @wrapper.header(options)
  end

  it "should not set the Set-Cookie header if the cookie option is an empty array" do
    options = { 'cookie' => [] }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).not_to receive(:[]=).with('Set-Cookie', anything())
    @wrapper.header(options)
  end

  it "should pass any other options through as headers" do
    options = { 'blah' => '200', 'bza' => 'hey' }
    expect(@response).to receive(:[]=).with('Content-Type', 'text/html')
    expect(@response).to receive(:[]=).with('blah', '200')
    expect(@response).to receive(:[]=).with('bza', 'hey')
    @wrapper.header(options)
  end

end
