#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet do
  
  let(:app) { mock "application" }
  let(:servlet) { Rack::Handler::Servlet.new(app) }
  
  shared_examples "env" do
    
    before do
      @servlet_request ||= org.jruby.rack.mock.MockHttpServletRequest.new
      @servlet_response ||= org.jruby.rack.mock.MockHttpServletResponse.new
      @servlet_env ||= org.jruby.rack.servlet.ServletRackEnvironment.new(
        @servlet_request, @servlet_response, @rack_context
      )
    end
    
    it "creates a hash with the Rack variables in it" do
      hash = servlet.create_env(@servlet_env)
      hash['rack.version'].should == Rack::VERSION
      hash['rack.multithread'].should == true
      hash['rack.multiprocess'].should == false
      hash['rack.run_once'].should == false
    end

    it "adds all attributes from the servlet request" do
      @servlet_request.setAttribute("PATH_INFO", "/path/info")
      @servlet_request.setAttribute("custom.attribute", true)

      env = servlet.create_env @servlet_env
      env["PATH_INFO"].should == "/path/info"
      env["custom.attribute"].should == true
    end

    it "is able to override cgi variables with request attributes of the same name" do
      { "REQUEST_METHOD" => "POST", 
        "SCRIPT_NAME" => "/override",
        "PATH_INFO" => "/override", 
        "REQUEST_URI" => "/override",
        "QUERY_STRING" => "override", 
        "SERVER_NAME" => "override",
        "SERVER_PORT" => 8080, 
        "SERVER_SOFTWARE" => "servy", 
        "REMOTE_HOST" => "override",
        "REMOTE_ADDR" => "192.168.0.1", 
        "REMOTE_USER" => "override" 
      }.each { |name, value| @servlet_request.setAttribute(name, value) }
      @rack_context.stub!(:getServerInfo).and_return 'Trinidad RULEZZ!'

      env = servlet.create_env @servlet_env
      env["REQUEST_METHOD"].should == "POST"
      env["SCRIPT_NAME"].should == "/override"
      env["PATH_INFO"].should == "/override"
      env["REQUEST_URI"].should == "/override"
      env["QUERY_STRING"].should == "override"
      env["SERVER_NAME"].should == "override"
      env["SERVER_PORT"].should == "8080"
      env["SERVER_SOFTWARE"].should == "servy"
      env["REMOTE_HOST"].should == "override"
      env["REMOTE_ADDR"].should == "192.168.0.1"
      env["REMOTE_USER"].should == "override"
    end

    it "is able to override headers with request attributes named HTTP_*" do
      { "HTTP_HOST" => "override", 
        "HTTP_ACCEPT" => "application/*",
        "HTTP_ACCEPT_ENCODING" => "bzip2", 
        "CONTENT_TYPE" => "application/override",
        "CONTENT_LENGTH" => 20 
      }.each { |name, value| @servlet_request.setAttribute(name, value) }
      { "Host" => "localhost", 
        "Accept" => "text/*", 
        "Accept-Encoding" => "gzip"
      }.each { |name, value| @servlet_request.addHeader(name, value) }
      @servlet_request.setContentType('text/plain')
      @servlet_request.setContent('12345'.to_java_bytes) # content length == 5

      env = servlet.create_env @servlet_env
      env["CONTENT_TYPE"].should == "application/override"
      env["CONTENT_LENGTH"].should == "20"
      env["HTTP_HOST"].should == "override"
      env["HTTP_ACCEPT"].should == "application/*"
      env["HTTP_ACCEPT_ENCODING"].should == "bzip2"
    end

    it "is not able to override CONTENT_TYPE or CONTENT_LENGTH to nil" do
      attrs = {"CONTENT_TYPE" => nil, "CONTENT_LENGTH" => -1 }
      attrs.each { |name, value| @servlet_request.setAttribute(name, value) }
      @servlet_request.setContentType('text/html')
      @servlet_request.setContent('1234567890'.to_java_bytes)

      env = servlet.create_env @servlet_env
      env["CONTENT_TYPE"].should == "text/html"
      env["CONTENT_LENGTH"].should == "10"
    end

    it "sets the rack.input and rack.errors keys" do
      @servlet_request.setScheme('http')
      @servlet_request.setContextPath('/foo')
      @servlet_request.setContent(''.to_java_bytes)
      @servlet_env.should_receive(:to_io).and_return(StringIO.new)
      
      env = servlet.create_env @servlet_env

      (input = env['rack.input']).should_not be nil
      [:gets, :read, :each].each { |sym| input.respond_to?(sym).should == true }
      (errors = env['rack.errors']).should_not be nil
      [:puts, :write, :flush].each { |sym| errors.respond_to?(sym).should == true }
    end

    it "sets the rack.errors to log via rack context" do
      env = servlet.create_env @servlet_env
      env['rack.errors'].should be_a JRuby::Rack::ServletLog

      @rack_context.should_receive(:log).with("bar").ordered
      @rack_context.should_receive(:log).with("huu").ordered

      env['rack.errors'].puts "bar"
      env['rack.errors'].write "huu"
    end

    it "sets env['HTTPS'] = 'on' if scheme is https" do
      @servlet_request.setScheme('https')

      env = servlet.create_env @servlet_env

      env['rack.url_scheme']
      env['HTTPS'].should == 'on'
    end

    it "adds cgi variables" do
      @servlet_request.setMethod('GET')
      @servlet_request.setContextPath('/app')
      @servlet_request.setServletPath('/script_name')
      @servlet_request.setPathInfo('/path/info')
      @servlet_request.setRequestURI('/app/script_name/path/info')
      @servlet_request.setQueryString('hello=there')
      @servlet_request.setServerName('serverhost')
      @servlet_request.setServerPort(80)
      @servlet_request.setRemoteAddr('127.0.0.1')
      @servlet_request.setRemoteHost('localhost')
      @servlet_request.setRemoteUser('admin')

      env = servlet.create_env @servlet_env

      env["REQUEST_METHOD"].should == "GET"
      env["SCRIPT_NAME"].should == "/app"
      env["PATH_INFO"].should == "/script_name/path/info"
      env["REQUEST_URI"].should == "/app/script_name/path/info?hello=there"
      env["QUERY_STRING"].should == "hello=there"
      env["SERVER_NAME"].should == "serverhost"
      env["SERVER_PORT"].should == "80"
      env["REMOTE_HOST"].should == "localhost"
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["REMOTE_USER"].should == "admin"
    end

    it "adds all variables under normal operation" do
      @servlet_request.setMethod('GET')
      @servlet_request.setScheme('http')
      @servlet_request.setContentType('text/html')
      @servlet_request.setContent('1'.to_java_bytes)
      @servlet_request.setContextPath('/app')
      @servlet_request.setServletPath('/script_name')
      @servlet_request.setPathInfo('/path/info')
      @servlet_request.setRequestURI('/app/script_name/path/info')
      @servlet_request.setQueryString('hello=there')
      @servlet_request.setServerName('serverhost')
      @servlet_request.setServerPort(80)
      @servlet_request.setRemoteAddr('127.0.0.1')
      @servlet_request.setRemoteHost('localhost')
      @servlet_request.setRemoteUser('admin')

      { "Host" => "localhost", 
        "Accept" => "text/*", 
        "Accept-Encoding" => "gzip"}.each do |name, value|
        @servlet_request.addHeader(name, value)
      end

      env = servlet.create_env @servlet_env
      env["rack.version"].should == Rack::VERSION
      env["CONTENT_TYPE"].should == "text/html"
      env["HTTP_HOST"].should == "localhost"
      env["HTTP_ACCEPT"].should == "text/*"
      env["REQUEST_METHOD"].should == "GET"
      env["SCRIPT_NAME"].should == "/app"
      env["PATH_INFO"].should == "/script_name/path/info"
      env["REQUEST_URI"].should == "/app/script_name/path/info?hello=there"
      env["QUERY_STRING"].should == "hello=there"
      env["SERVER_NAME"].should == "serverhost"
      env["SERVER_PORT"].should == "80"
      env["REMOTE_HOST"].should == "localhost"
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["REMOTE_USER"].should == "admin"
    end

    it "sets environment variables to the empty string if their value is nil" do
      @servlet_request.setMethod(nil) # by default it's ''
      @servlet_request.setServerName(nil) # default 'localhost'
      @servlet_request.setRemoteHost(nil) # default 'localhost'
      @servlet_request.setRemoteAddr(nil) # default '127.0.0.1'
      
      env = servlet.create_env @servlet_env
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

    it "calculates path info from the servlet path and the path info" do
      @servlet_request.setContextPath('/context')
      @servlet_request.setServletPath('/path')

      env = servlet.create_env @servlet_env
      env["SCRIPT_NAME"].should == "/context"
      env["PATH_INFO"].should == "/path"
    end

    it "works correctly when running under the root context" do
      @servlet_request.setContextPath('')
      @servlet_request.setServletPath('/')

      env = servlet.create_env @servlet_env
      env["PATH_INFO"].should == "/"
      env["SCRIPT_NAME"].should == ""
    end

    it "ignores servlet path when it is not part of the request URI" do    
      # This craziness is what happens in the default Tomcat 7 install
      @servlet_request.setContextPath('/context')
      @servlet_request.setServletPath('/index.jsp')
      @servlet_request.setRequestURI('/context/')

      env = servlet.create_env @servlet_env
      env["SCRIPT_NAME"].should == "/context"
      env["PATH_INFO"].should == "/"
    end

    it "includes query string in the request URI" do
      @servlet_request.setRequestURI('/some/path')
      @servlet_request.setQueryString('some=query&string')

      env = servlet.create_env @servlet_env
      env["REQUEST_URI"].should == "/some/path?some=query&string"
    end

    it "puts content type and content length in the hash without the HTTP_ prefix" do
      @servlet_request.addHeader("Content-Type", "text/plain")
      @servlet_request.setContentType('text/html')
      @servlet_request.setContent('0123456789'.to_java_bytes) # length 10

      env = servlet.create_env @servlet_env
      env["CONTENT_TYPE"].should == "text/html"
      env["CONTENT_LENGTH"].should == "10"
      env["HTTP_CONTENT_TYPE"].should == nil
      env.should_not have_key("HTTP_CONTENT_TYPE")
      env["HTTP_CONTENT_LENGTH"].should == nil
      env.should_not have_key("HTTP_CONTENT_LENGTH")
    end

    it "puts the other headers in the hash upcased and underscored and prefixed with HTTP_" do
      { "Host" => "localhost", 
        "Accept" => "text/*", 
        "Accept-Encoding" => "gzip",
        "Content-Length" => "0" 
      }.each { |name, value| @servlet_request.addHeader(name, value) }

      env = servlet.create_env @servlet_env
      env["CONTENT_TYPE"].should == nil
      env.should_not have_key("CONTENT_TYPE")
      env["CONTENT_LENGTH"].should == nil
      env.should_not have_key("CONTENT_LENGTH")
      env["HTTP_HOST"].should == "localhost"
      env["HTTP_ACCEPT"].should == "text/*"
      env["HTTP_ACCEPT_ENCODING"].should == "gzip"
    end

    it "handles header names that have more than one dash in them" do
      { "X-Forwarded-Proto" => "https", 
        "If-None-Match" => "abcdef",
        "If-Modified-Since" => "today", 
        "X-Some-Really-Long-Header" => "yeap" 
      }.each { |name, value| @servlet_request.addHeader(name, value) }

      env = servlet.create_env @servlet_env
      env["HTTP_X_FORWARDED_PROTO"].should == "https"
      env["HTTP_IF_NONE_MATCH"].should == "abcdef"
      env["HTTP_IF_MODIFIED_SINCE"].should == "today"
      env["HTTP_X_SOME_REALLY_LONG_HEADER"].should == "yeap"
    end

    it "returns the servlet request when queried with java.servlet_request" do
      env = servlet.create_env @servlet_env
      env['java.servlet_request'].should == @servlet_request
    end

    it "returns the servlet response when queried with java.servlet_response" do
      env = servlet.create_env @servlet_env
      env['java.servlet_response'].should == @servlet_response
    end
    
  end
  
  describe 'env (default)' do
    
    it_behaves_like "env"
    
  end
  
  context "servlet" do
    
    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new
      @servlet_request = org.jruby.rack.mock.MockHttpServletRequest.new(@servlet_context)
      @servlet_response = org.jruby.rack.mock.MockHttpServletResponse.new
      @servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
        @servlet_request, @servlet_response, @rack_context
      )
    end

    it "returns the servlet context when queried with java.servlet_context" do
      env = servlet.create_env @servlet_env
      
      env['java.servlet_context'].should_not be nil
      env['java.servlet_context'].should == @rack_context
    end
    
    it "returns the servlet context when queried with java.servlet_context 3.0" do
      # HACK to emulate Servlet API 3.0 MockHttpServletRequest has getServletContext :
      env = Rack::Handler::Servlet::DefaultEnv.new(@servlet_request).to_hash
      
      env['java.servlet_context'].should_not be nil
      env['java.servlet_context'].should == @servlet_context
      begin
        env['java.servlet_context'].should == @servlet_context
      rescue NoMethodError
        (env['java.servlet_context'] == @servlet_context).should == true
      end
    end
    
    it "returns the servlet request when queried with java.servlet_request" do
      env = servlet.create_env @servlet_env
      env['java.servlet_request'].should == @servlet_request
    end
    
    it "returns the servlet response when queried with java.servlet_response" do
      env = servlet.create_env @servlet_env
      env['java.servlet_response'].should == @servlet_response
    end
    
  end
  
  describe "call" do

    it "delegates to the inner application after constructing the env hash" do
      servlet.should_receive(:create_env).and_return({})

      servlet_env = mock("servlet request")
      app.should_receive(:call)

      response = servlet.call(servlet_env)
      response.should respond_to(:respond)
    end

    it "raises an error when it failed to load the application" do
      lambda { Rack::Handler::Servlet.new(nil) }.should raise_error(RuntimeError)
      lambda { Rack::Handler::Servlet.new(nil) }.should_not raise_error(NoMethodError)
    end
    
  end
  
end