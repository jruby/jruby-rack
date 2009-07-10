#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack'
require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet, "create_env" do
  before :each do
    @servlet = Rack::Handler::Servlet.new(nil)
    @servlet_env = mock "servlet request"
    @env = org.jruby.rack.servlet.ServletRackEnvironment.new @servlet_env
    @servlet_env.stub!(:getAttributeNames).and_return enumeration([])
  end

  def stub_env(options = {})
    options = {
      :getContextPath => nil,
      :getMethod => nil,
      :getServletPath => "",
      :getPathInfo => nil,
      :getRequestURI => nil,
      :getQueryString => nil,
      :getServerName => nil,
      :getRemoteHost => nil,
      :getRemoteAddr => nil,
      :getRemoteUser => nil,
      :getServerPort => 80}.merge(options)
    options.each {|k,v| @servlet_env.stub!(k).and_return v}
  end

  class ArrayEnumeration
    include java.util.Enumeration
    def initialize(arr)
      @arr = arr
      @pos = 0
    end
    def hasMoreElements
      @pos < @arr.length
    end
    def nextElement
      raise java.util.NoSuchElementException.new("no more elements") unless hasMoreElements
      pos = @pos
      @pos += 1
      @arr[pos]
    end
  end

  def enumeration(arr)
    ArrayEnumeration.new(arr)
  end

  it "should create a hash with the Rack variables in it" do
    hash = @servlet.create_lazy_env(@env)
    hash['rack.version'].should == Rack::VERSION
    hash['rack.multithread'].should == true
    hash['rack.multiprocess'].should == false
    hash['rack.run_once'].should == false
  end

  it "should add all attributes from the servlet request" do
    @servlet_env.should_receive(:getAttributeNames).and_return enumeration(["PATH_INFO", "custom.attribute"])
    attrs = {"PATH_INFO" => "/path/info", "custom.attribute" => true}
    (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
    env = @servlet.create_lazy_env @env
    env["PATH_INFO"].should == "/path/info"
    env["custom.attribute"].should == true
  end

  it "should be able to override cgi variables with request attributes of the same name" do
    @servlet_env.should_receive(:getAttributeNames).and_return(enumeration(
      %w(REQUEST_METHOD SCRIPT_NAME PATH_INFO REQUEST_URI QUERY_STRING
         SERVER_NAME SERVER_PORT REMOTE_HOST REMOTE_ADDR REMOTE_USER)))
    attrs = { "REQUEST_METHOD" => "POST", "SCRIPT_NAME" => "/override",
      "PATH_INFO" => "/override", "REQUEST_URI" => "/override",
      "QUERY_STRING" => "override", "SERVER_NAME" => "override",
      "SERVER_PORT" => 8080, "REMOTE_HOST" => "override",
      "REMOTE_ADDR" => "192.168.0.1", "REMOTE_USER" => "override" }
    (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
    stub_env({ :getMethod => "GET",
               :getContextPath => "/app",
               :getServletPath => "/script_name",
               :getPathInfo => "/path/info",
               :getRequestURI => "/app/script_name/path/info",
               :getQueryString => "hello=there",
               :getServerName => "localhost",
               :getServerPort => 80,
               :getRemoteHost => "localhost",
               :getRemoteAddr => "127.0.0.1",
               :getRemoteUser => "admin"
             })

    env = @servlet.create_lazy_env @env

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

  it "should be able to override headers with request attributes named HTTP_*" do
    @servlet_env.should_receive(:getAttributeNames).and_return(enumeration(
      %w(HTTP_HOST HTTP_ACCEPT HTTP_ACCEPT_ENCODING CONTENT_TYPE CONTENT_LENGTH)))
    attrs = {"HTTP_HOST" => "override", "HTTP_ACCEPT" => "application/*",
      "HTTP_ACCEPT_ENCODING" => "bzip2", "CONTENT_TYPE" => "application/override",
      "CONTENT_LENGTH" => 20 }
    (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
    enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip"}
    stub_env :getHeaderNames => enumeration(enum.keys), :getContentType => "text/plain", :getContentLength => 10
    (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = @servlet.create_lazy_env @env
    env["CONTENT_TYPE"].should == "application/override"
    env["CONTENT_LENGTH"].should == "20"
    env["HTTP_HOST"].should == "override"
    env["HTTP_ACCEPT"].should == "application/*"
    env["HTTP_ACCEPT_ENCODING"].should == "bzip2"
  end

  it "should not be able to override CONTENT_TYPE or CONTENT_LENGTH to nil" do
    @servlet_env.should_receive(:getAttributeNames).and_return(enumeration(%w(CONTENT_TYPE CONTENT_LENGTH)))
    attrs = {"CONTENT_TYPE" => nil, "CONTENT_LENGTH" => -1 }
    (class << @servlet_env; self; end).send(:define_method, :getAttribute) {|k| attrs[k]}
    stub_env :getContentType => "text/html", :getContentLength => 10
    env = @servlet.create_lazy_env @env
    env["CONTENT_TYPE"].should == "text/html"
    env["CONTENT_LENGTH"].should == "10"
  end

  it "should set the input and error keys" do
    stub_env :getScheme => "http", :getContextPath => "/foo"
    @env.stub!(:to_io).and_return StringIO.new
    env = @servlet.create_lazy_env @env
    (input = env['rack.input']).should_not be_nil
    [:gets, :read, :each].each {|sym| input.respond_to?(sym).should == true }
    (errors = env['rack.errors']).should_not be_nil
    [:puts, :write, :flush].each {|sym| errors.respond_to?(sym).should == true }
    env['java.servlet_request'].should == @servlet_env
  end

  it "should add cgi variables" do
    stub_env({ :getMethod => "GET",
               :getContextPath => "/app",
               :getServletPath => "/script_name",
               :getPathInfo => "/path/info",
               :getRequestURI => "/app/script_name/path/info",
               :getQueryString => "hello=there",
               :getServerName => "localhost",
               :getServerPort => 80,
               :getRemoteHost => "localhost",
               :getRemoteAddr => "127.0.0.1",
               :getRemoteUser => "admin"
             })

    env = @servlet.create_lazy_env @env
    env["REQUEST_METHOD"].should == "GET"
    env["SCRIPT_NAME"].should == "/app/script_name"
    env["PATH_INFO"].should == "/script_name/path/info"
    env["REQUEST_URI"].should == "/app/script_name/path/info?hello=there"
    env["QUERY_STRING"].should == "hello=there"
    env["SERVER_NAME"].should == "localhost"
    env["SERVER_PORT"].should == "80"
    env["REMOTE_HOST"].should == "localhost"
    env["REMOTE_ADDR"].should == "127.0.0.1"
    env["REMOTE_USER"].should == "admin"
  end

  it "should add all variables under normal operation" do
    enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip"}
    (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }
    @env.stub!(:to_io).and_return StringIO.new
    stub_env({ :getScheme => "http",
               :getContextPath => "/foo",
               :getContentType => "text/html",
               :getContentLength => 1,
               :getHeaderNames => enumeration(enum.keys),
               :getMethod => "GET",
               :getContextPath => "/app",
               :getServletPath => "/script_name",
               :getPathInfo => "/path/info",
               :getRequestURI => "/app/script_name/path/info",
               :getQueryString => "hello=there",
               :getServerName => "localhost",
               :getServerPort => 80,
               :getRemoteHost => "localhost",
               :getRemoteAddr => "127.0.0.1",
               :getRemoteUser => "admin"
             })

    env = @servlet.create_env @env
    env["rack.version"].should == Rack::VERSION
    env["CONTENT_TYPE"].should == "text/html"
    env["HTTP_HOST"].should == "localhost"
    env["HTTP_ACCEPT"].should == "text/*"
    env["REQUEST_METHOD"].should == "GET"
    env["SCRIPT_NAME"].should == "/app/script_name"
    env["PATH_INFO"].should == "/script_name/path/info"
    env["REQUEST_URI"].should == "/app/script_name/path/info?hello=there"
    env["QUERY_STRING"].should == "hello=there"
    env["SERVER_NAME"].should == "localhost"
    env["SERVER_PORT"].should == "80"
    env["REMOTE_HOST"].should == "localhost"
    env["REMOTE_ADDR"].should == "127.0.0.1"
    env["REMOTE_USER"].should == "admin"
  end

  it "should set environment variables to the empty string if their value is nil" do
    stub_env
    env = @servlet.create_lazy_env @env
    env["REQUEST_METHOD"].should == "GET"
    env["SCRIPT_NAME"].should == ""
    env["PATH_INFO"].should == ""
    env["REQUEST_URI"].should == ""
    env["QUERY_STRING"].should == ""
    env["SERVER_NAME"].should == ""
    env["REMOTE_HOST"].should == ""
    env["REMOTE_ADDR"].should == ""
    env["REMOTE_USER"].should == ""
  end

  it "should calculate path info from the servlet path and the path info" do
    stub_env :getContextPath => "/context", :getServletPath => "/path"
    env = @servlet.create_lazy_env @env
    env["SCRIPT_NAME"].should == "/context/path"
    env["PATH_INFO"].should == "/path"
  end

  it "should work correctly when running under the root context" do
    stub_env :getContextPath => "", :getServletPath => "/"
    env = @servlet.create_lazy_env @env
    env["PATH_INFO"].should == "/"
    env["SCRIPT_NAME"].should == ""
  end

  it "should include query string in the request URI" do
    stub_env :getRequestURI => "/some/path", :getQueryString => "some=query&string"
    env = @servlet.create_lazy_env @env
    env["REQUEST_URI"].should == "/some/path?some=query&string"
  end

  it "should put content type and content length in the hash without the HTTP_ prefix" do
    enum = {"Content-Type" => "text/plain"}
    stub_env :getHeaderNames => enumeration(enum.keys), :getContentType => "text/html", :getContentLength => 10
    @servlet_env.stub!(:getHeader).and_return {|h| enum[h]}
    (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = @servlet.create_lazy_env @env
    env["CONTENT_TYPE"].should == "text/html"
    env["CONTENT_LENGTH"].should == "10"
    env["HTTP_CONTENT_TYPE"].should == nil
    env.should_not have_key("HTTP_CONTENT_TYPE")
    env["HTTP_CONTENT_LENGTH"].should == nil
    env.should_not have_key("HTTP_CONTENT_LENGTH")
  end

  it "should put the other headers in the hash upcased and underscored and prefixed with HTTP_" do
    enum = {"Host" => "localhost", "Accept" => "text/*", "Accept-Encoding" => "gzip",
      "Content-Length" => "0" }
    stub_env :getHeaderNames => enumeration(enum.keys), :getContentType => nil, :getContentLength => -1
    (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = @servlet.create_lazy_env @env
    env["CONTENT_TYPE"].should == nil
    env.should_not have_key("CONTENT_TYPE")
    env["CONTENT_LENGTH"].should == nil
    env.should_not have_key("CONTENT_LENGTH")
    env["HTTP_HOST"].should == "localhost"
    env["HTTP_ACCEPT"].should == "text/*"
    env["HTTP_ACCEPT_ENCODING"].should == "gzip"
  end

  it "should handle header names that have more than one dash in them" do
    enum = {"X-Forwarded-Proto" => "https", "If-None-Match" => "abcdef",
      "If-Modified-Since" => "today", "X-Some-Really-Long-Header" => "yeap"}
    stub_env :getHeaderNames => enumeration(enum.keys), :getContentType => nil, :getContentLength => -1
    (class << @servlet_env; self; end).send(:define_method, :getHeader) {|h| enum[h] }

    env = @servlet.create_lazy_env @env
    env["HTTP_X_FORWARDED_PROTO"].should == "https"
    env["HTTP_IF_NONE_MATCH"].should == "abcdef"
    env["HTTP_IF_MODIFIED_SINCE"].should == "today"
    env["HTTP_X_SOME_REALLY_LONG_HEADER"].should == "yeap"
  end
end

describe Rack::Handler::Servlet, "call" do
  before :each do
    @app = mock "application"
    @servlet = Rack::Handler::Servlet.new(@app)
  end

  it "should delegate to the inner application after constructing the env hash" do
    @servlet.should_receive(:create_env).and_return({})

    servlet_env = mock("servlet request")
    @app.should_receive(:call)

    response = @servlet.call(servlet_env)
    response.should respond_to(:respond)
  end
end
