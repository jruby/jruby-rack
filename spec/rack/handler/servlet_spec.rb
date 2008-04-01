#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack'
require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
    @servlet_env = mock "servlet request"
  end

  describe "env_hash" do
    it "should create a hash with the Rack variables in it" do
      hash = @servlet.env_hash
      hash['rack.version'].should == Rack::VERSION
      hash['rack.multithread'].should == true
      hash['rack.multiprocess'].should == false
      hash['rack.run_once'].should == false
    end
  end

  describe "add_servlet_request_attributes" do
    it "should add all attributes from the servlet request" do
      @servlet_env.stub!(:getAttributeNames).and_return ["PATH_INFO", "custom.attribute"]
      attrs = {"PATH_INFO" => "/path/info", "custom.attribute" => true}
      (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
      env = {}
      @servlet.add_servlet_request_attributes @servlet_env, env
      env["PATH_INFO"].should == "/path/info"
      env["custom.attribute"].should == true
    end

    it "should be able to override cgi variables" do
      @servlet_env.stub!(:getAttributeNames).and_return(
          %w(REQUEST_METHOD SCRIPT_NAME PATH_INFO REQUEST_URI QUERY_STRING
             SERVER_NAME SERVER_PORT REMOTE_HOST REMOTE_ADDR REMOTE_USER))
      attrs = { "REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/override",
        "PATH_INFO" => "/override", "REQUEST_URI" => "/override",
        "QUERY_STRING" => "override", "SERVER_NAME" => "override",
        "SERVER_PORT" => 8080, "REMOTE_HOST" => "override",
        "REMOTE_ADDR" => "192.168.0.1", "REMOTE_USER" => "override" }
      (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
      @servlet_env.stub!(:getMethod).and_return "GET"
      @servlet_env.stub!(:getContextPath).and_return "/app"
      @servlet_env.stub!(:getServletPath).and_return "/script_name"
      @servlet_env.stub!(:getPathInfo).and_return "/path/info"
      @servlet_env.stub!(:getRequestURI).and_return "/app/script_name/path/info"
      @servlet_env.stub!(:getQueryString).and_return "hello=there"
      @servlet_env.stub!(:getServerName).and_return "localhost"
      @servlet_env.stub!(:getServerPort).and_return 80
      @servlet_env.stub!(:getRemoteHost).and_return "localhost"
      @servlet_env.stub!(:getRemoteAddr).and_return "127.0.0.1"
      @servlet_env.stub!(:getRemoteUser).and_return "admin"

      env = {}
      @servlet.add_servlet_request_attributes(@servlet_env, env)
      @servlet.add_variables(@servlet_env, env)

      env["REQUEST_METHOD"].should == "POST"
      env["SCRIPT_NAME"].should == "/override"
      env["PATH_INFO"].should == "/override"
      env["REQUEST_URI"].should == "/override"
      env["QUERY_STRING"].should == "override"
      env["SERVER_NAME"].should == "override"
      env["SERVER_PORT"].should == "8080"
      env["REMOTE_HOST"].should == "override"
      env["REMOTE_ADDR"].should == "192.168.0.1"
      env["REMOTE_USER"].should == "override"
    end

    it "should be able to override headers" do
      @servlet_env.stub!(:getAttributeNames).and_return(
        %w(HTTP_HOST HTTP_ACCEPT HTTP_ACCEPT_ENCODING CONTENT_TYPE CONTENT_LENGTH))
      attrs = {"HTTP_HOST" => "override", "HTTP_ACCEPT" => "application/*",
        "HTTP_ACCEPT_ENCODING" => "bzip2", "CONTENT_TYPE" => "application/override",
        "CONTENT_LENGTH" => 20 }
      (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
      enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip"}
      @servlet_env.stub!(:getHeaderNames).and_return enum.keys
      @servlet_env.stub!(:getContentType).and_return "text/plain"
      @servlet_env.stub!(:getContentLength).and_return(10)
      (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

      env = {}
      @servlet.add_servlet_request_attributes(@servlet_env, env)
      @servlet.add_headers(@servlet_env, env)
      env["CONTENT_TYPE"].should == "application/override"
      env["CONTENT_LENGTH"].should == "20"
      env["HTTP_HOST"].should == "override"
      env["HTTP_ACCEPT"].should == "application/*"
      env["HTTP_ACCEPT_ENCODING"].should == "bzip2"
    end
  end

  describe "add_input_errors_scheme" do
    it "should set the input and error keys" do
      @servlet_env.stub!(:to_io).and_return StringIO.new
      @servlet_env.stub!(:getScheme).and_return "http"
      @servlet_env.stub!(:getContextPath).and_return "/foo"
      env = {}
      @servlet.add_input_errors_scheme @servlet_env, env
      (input = env['rack.input']).should_not be_nil
      [:gets, :read, :each].each {|sym| input.respond_to?(sym).should == true }
      (errors = env['rack.errors']).should_not be_nil
      [:puts, :write, :flush].each {|sym| errors.respond_to?(sym).should == true }
      env['java.servlet_request'].should_not be_nil
    end
  end

  describe "add_variables" do
    it "should add cgi variables" do
      @servlet_env.stub!(:getMethod).and_return "GET"
      @servlet_env.stub!(:getContextPath).and_return "/app"
      @servlet_env.stub!(:getServletPath).and_return "/script_name"
      @servlet_env.stub!(:getPathInfo).and_return "/path/info"
      @servlet_env.stub!(:getRequestURI).and_return "/app/script_name/path/info"
      @servlet_env.stub!(:getQueryString).and_return "hello=there"
      @servlet_env.stub!(:getServerName).and_return "localhost"
      @servlet_env.stub!(:getServerPort).and_return 80
      @servlet_env.stub!(:getRemoteHost).and_return "localhost"
      @servlet_env.stub!(:getRemoteAddr).and_return "127.0.0.1"
      @servlet_env.stub!(:getRemoteUser).and_return "admin"
      env = {}
      @servlet.add_variables(@servlet_env, env)
      env["REQUEST_METHOD"].should == "GET"
      env["SCRIPT_NAME"].should == "/app/script_name"
      env["PATH_INFO"].should == "/script_name/path/info"
      env["REQUEST_URI"].should == "/app/script_name/path/info"
      env["QUERY_STRING"].should == "hello=there"
      env["SERVER_NAME"].should == "localhost"
      env["SERVER_PORT"].should == "80"
      env["REMOTE_HOST"].should == "localhost"
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["REMOTE_USER"].should == "admin"
    end

    it "should set environment variables to the empty string if their value is nil" do
      @servlet_env.stub!(:getContextPath).and_return nil
      @servlet_env.stub!(:getMethod).and_return nil
      @servlet_env.stub!(:getServletPath).and_return ""
      @servlet_env.stub!(:getPathInfo).and_return nil
      @servlet_env.stub!(:getRequestURI).and_return nil    
      @servlet_env.stub!(:getQueryString).and_return nil
      @servlet_env.stub!(:getServerName).and_return nil
      @servlet_env.stub!(:getRemoteHost).and_return nil
      @servlet_env.stub!(:getRemoteAddr).and_return nil
      @servlet_env.stub!(:getRemoteUser).and_return nil
      @servlet_env.stub!(:getServerPort).and_return 80
      env = {}
      @servlet.add_variables(@servlet_env, env)
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

    it "should calculate path info from the servlet path and the path info" do
      @servlet_env.stub!(:getContextPath).and_return "/context"
      @servlet_env.stub!(:getMethod).and_return nil
      @servlet_env.stub!(:getServletPath).and_return "/path"
      @servlet_env.stub!(:getPathInfo).and_return nil
      @servlet_env.stub!(:getRequestURI).and_return nil
      @servlet_env.stub!(:getQueryString).and_return nil
      @servlet_env.stub!(:getServerName).and_return nil
      @servlet_env.stub!(:getRemoteHost).and_return nil
      @servlet_env.stub!(:getRemoteAddr).and_return nil
      @servlet_env.stub!(:getRemoteUser).and_return nil
      @servlet_env.stub!(:getServerPort).and_return 80
      env = {}
      @servlet.add_variables(@servlet_env, env)
      env["PATH_INFO"].should == "/path"
    end
  end

  describe "add_headers" do
    it "should put content type and content length in the hash without the HTTP_ prefix" do
      enum = {"Content-Type" => "text/plain"}
      @servlet_env.stub!(:getHeaderNames).and_return enum.keys
      @servlet_env.stub!(:getContentType).and_return "text/html"
      @servlet_env.stub!(:getContentLength).and_return 10
      @servlet_env.stub!(:getHeader).and_return {|h| enum[h]}
      (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

      env = {}
      @servlet.add_headers(@servlet_env, env)
      env["CONTENT_TYPE"].should == "text/html"
      env["CONTENT_LENGTH"].should == "10"
      env.should_not have_key?("HTTP_CONTENT_TYPE")
      env.should_not have_key?("HTTP_CONTENT_LENGTH")    
    end

    it "should put the other headers in the hash upcased and underscored and prefixed with HTTP_" do
      enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip",
        "Content-Length" => "0" }
      @servlet_env.stub!(:getHeaderNames).and_return enum.keys
      @servlet_env.stub!(:getContentType).and_return nil
      @servlet_env.stub!(:getContentLength).and_return(-1)
      (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

      env = {}
      @servlet.add_headers(@servlet_env, env)
      env.should_not have_key?("CONTENT_TYPE")
      env.should_not have_key?("CONTENT_LENGTH")
      env["HTTP_HOST"].should == "localhost"
      env["HTTP_ACCEPT"].should == "text/*"
      env["HTTP_ACCEPT_ENCODING"].should == "gzip"
    end
  end
end

describe Rack::Handler::Servlet, "call" do
  before :each do
    @app = mock "application"
    @servlet = Rack::Handler::Servlet.new(@app)
  end

  it "should delegate to the inner application after constructing the env hash" do
    @servlet.should_receive(:add_input_errors_scheme).ordered
    @servlet.should_receive(:add_servlet_request_attributes).ordered
    @servlet.should_receive(:add_variables).ordered
    @servlet.should_receive(:add_headers).ordered
    
    servlet_env = mock("servlet request")
    @app.should_receive(:call)
    
    response = @servlet.call(servlet_env)
    response.should respond_to(:respond)
  end
end