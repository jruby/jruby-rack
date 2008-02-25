#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack'
require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet, "env_hash" do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
  end

  it "should create a hash with the Rack variables in it" do
    hash = @servlet.env_hash
    hash['rack.version'].should == Rack::VERSION
    hash['rack.multithread'].should == true
    hash['rack.multiprocess'].should == false
    hash['rack.run_once'].should == false
  end
end

describe Rack::Handler::Servlet, "add_input_errors_scheme" do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
  end

  it "should set the input and error keys" do
    servlet_env = mock "servlet request"
    servlet_env.stub!(:to_io).and_return StringIO.new
    servlet_env.stub!(:getScheme).and_return "http"
    env = {}
    @servlet.add_input_errors_scheme servlet_env, env
    (input = env['rack.input']).should_not be_nil
    [:gets, :read, :each].each {|sym| input.respond_to?(sym).should == true }
    (errors = env['rack.errors']).should_not be_nil
    [:puts, :write, :flush].each {|sym| errors.respond_to?(sym).should == true }
    env['java.servlet_request'].should_not be_nil
  end
end

describe Rack::Handler::Servlet, "add_variables" do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
  end

  it "should add cgi variables" do
    servlet_env = mock "servlet request"
    servlet_env.stub!(:getMethod).and_return "GET"
    servlet_env.stub!(:getServletPath).and_return "/path/info/script_name"
    servlet_env.stub!(:getPathInfo).and_return "/path/info"
    servlet_env.stub!(:getRequestURI).and_return "/request/uri"
    servlet_env.stub!(:getQueryString).and_return "hello=there"
    servlet_env.stub!(:getServerName).and_return "localhost"
    servlet_env.stub!(:getServerPort).and_return 80
    servlet_env.stub!(:getRemoteHost).and_return "localhost"
    servlet_env.stub!(:getRemoteAddr).and_return "127.0.0.1"
    servlet_env.stub!(:getRemoteUser).and_return "admin"
    env = {}
    @servlet.add_variables(servlet_env, env)
    env["REQUEST_METHOD"].should == "GET"
    env["SCRIPT_NAME"].should == "/path/info/script_name"
    env["PATH_INFO"].should == "/path/info"
    env["REQUEST_URI"].should == "/request/uri"
    env["QUERY_STRING"].should == "hello=there"
    env["SERVER_NAME"].should == "localhost"
    env["SERVER_PORT"].should == "80"
    env["REMOTE_HOST"].should == "localhost"
    env["REMOTE_ADDR"].should == "127.0.0.1"
    env["REMOTE_USER"].should == "admin"
  end

  it "should not add environment variables if their value is nil" do
    servlet_env = mock "servlet request"
    servlet_env.stub!(:getMethod).and_return nil
    servlet_env.stub!(:getServletPath).and_return nil
    servlet_env.stub!(:getPathInfo).and_return nil
    servlet_env.stub!(:getRequestURI).and_return nil    
    servlet_env.stub!(:getQueryString).and_return nil
    servlet_env.stub!(:getServerName).and_return nil
    servlet_env.stub!(:getRemoteHost).and_return nil
    servlet_env.stub!(:getRemoteAddr).and_return nil
    servlet_env.stub!(:getRemoteUser).and_return nil
    servlet_env.stub!(:getServerPort).and_return 80
    env = {}
    @servlet.add_variables(servlet_env, env)
    env.should have_key("REQUEST_METHOD")
    env.should have_key("SCRIPT_NAME")
    env.should have_key("PATH_INFO")
    env.should have_key("REQUEST_URI")
    env.should have_key("QUERY_STRING")
    env.should have_key("SERVER_NAME")
    env.should have_key("REMOTE_HOST")
    env.should have_key("REMOTE_ADDR")
    env.should have_key("REMOTE_USER")
  end
end

describe Rack::Handler::Servlet, "add_headers" do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
  end

  it "should put content type and content length in the hash without the HTTP_ prefix" do
    enum = {"Content-Type" => "text/plain"}
    servlet_env = mock "servlet request"
    servlet_env.stub!(:getHeaderNames).and_return enum.keys
    servlet_env.stub!(:getContentType).and_return "text/html"
    servlet_env.stub!(:getContentLength).and_return 10
    (class << servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = {}
    @servlet.add_headers(servlet_env, env)
    env["CONTENT_TYPE"].should == "text/html"
    env["CONTENT_LENGTH"].should == "10"
    env.should_not have_key?("HTTP_CONTENT_TYPE")
    env.should_not have_key?("HTTP_CONTENT_LENGTH")    
  end

  it "should put the other headers in the hash upcased and underscored and prefixed with HTTP_" do
    enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip",
      "Content-Length" => "0" }
    servlet_env = mock "servlet request"
    servlet_env.stub!(:getHeaderNames).and_return enum.keys
    servlet_env.stub!(:getContentType).and_return nil
    servlet_env.stub!(:getContentLength).and_return(-1)
    (class << servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = {}
    @servlet.add_headers(servlet_env, env)
    env.should_not have_key?("CONTENT_TYPE")
    env.should_not have_key?("CONTENT_LENGTH")
    env["HTTP_HOST"].should == "localhost"
    env["HTTP_ACCEPT"].should == "text/*"
    env["HTTP_ACCEPT_ENCODING"].should == "gzip"
  end
end

describe Rack::Handler::Servlet, "call" do
  before :each do
    @app = mock "application"
    @servlet = Rack::Handler::Servlet.new(@app)
  end

  it "should delegate to the inner application after constructing the env hash" do
    @servlet.should_receive(:add_input_errors_scheme)
    @servlet.should_receive(:add_variables)
    @servlet.should_receive(:add_headers)
    
    servlet_env = mock("servlet request")
    @app.should_receive(:call)
    
    result = @servlet.call(servlet_env)
    [:writeStatus, :writeHeaders, :writeBody].each {|k| result.respond_to?(k).should == true }
  end
end

describe Rack::Handler::Servlet::Result do
  before :each do
    @status, @headers, @body = mock("status"), mock("headers"), mock("body")
    @servlet_response = mock "servlet response"
    @result = Rack::Handler::Servlet::Result.new([@status, @headers, @body])
  end

  it "should write the status to the servlet response" do
    @status.should_receive(:to_i).and_return(200)
    @servlet_response.should_receive(:setStatus).with(200)
    @result.writeStatus(@servlet_response)
  end

  it "should write the headers to the servlet response" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Server",  "Apache/2.2.x"
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:setHeader).with("Server", "Apache/2.2.x")
    @result.writeHeaders(@servlet_response)
  end

  it "should write the body to the servlet response" do
    @body.should_receive(:each).and_return do |block|
      block.call "hello"
      block.call "there"
    end
    stream = mock "output stream"
    @servlet_response.stub!(:getOutputStream).and_return stream
    stream.should_receive(:write).exactly(2).times
    
    @result.writeBody(@servlet_response)
  end
end