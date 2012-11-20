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
      @servlet_request ||= org.jruby.rack.mock.MockHttpServletRequest.new(@servlet_context)
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
      set_rack_input @servlet_env
      
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

    it "exposes the servlet request" do
      env = servlet.create_env @servlet_env
      env['java.servlet_request'].should == @servlet_request
    end

    it "exposes the servlet response" do
      env = servlet.create_env @servlet_env
      env['java.servlet_response'].should == @servlet_response
    end

    it "exposes the servlet context" do
      env = servlet.create_env @servlet_env
      env['java.servlet_context'].should be_a javax.servlet.ServletContext
      # Failure/Error: env['java.servlet_context'].should == @servlet_context
      # NoMethodError:
      #  private method `pretty_print' called for #<RSpec::Mocks::ErrorGenerator:0x1e9d469>
      #begin
      #  env['java.servlet_context'].should == @servlet_context
      #rescue NoMethodError
      #  ( env['java.servlet_context'] == @servlet_context ).should be true
      #end
    end

    it "exposes the rack context" do
      env = servlet.create_env @servlet_env
      env['jruby.rack.context'].should == @rack_context
    end
    
  end
  
  shared_examples "(eager)rack-env" do
    
    before do
      @servlet_request = org.jruby.rack.mock.MockHttpServletRequest.new(@servlet_context)
      @servlet_response = org.jruby.rack.mock.MockHttpServletResponse.new
      @servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
        @servlet_request, @servlet_response, @rack_context
      )
    end
    
    let(:filled_servlet_env) do
      @servlet_request.setMethod('GET')
      @servlet_request.setContextPath('/main')
      @servlet_request.setServletPath('/app1')
      @servlet_request.setPathInfo('/path/info')
      @servlet_request.setRequestURI('/main/app1/path/info')
      @servlet_request.setQueryString('hello=there')
      @servlet_request.setServerName('serverhost')
      @servlet_request.setServerPort(80)
      @rack_context.stub!(:getServerInfo).and_return 'Trinidad'
      @servlet_request.setRemoteAddr('127.0.0.1')
      @servlet_request.setRemoteHost('localhost')
      @servlet_request.setRemoteUser('admin')
      @servlet_request.setContentType('text/plain')
      @servlet_request.setContent('1234'.to_java_bytes) # Content-Length
      { "X-Forwarded-Proto" => "https",
        "If-None-Match" => "03273f2f207cb7864f217458f0f85e4e",
        "If-Modified-Since" => "Sun, Aug 19 2012 12:11:50 +0200",
        "Referer" => "http://www.example.com",
        "X-Some-Really-Long-Header" => "42"
      }.each { |name, value| @servlet_request.addHeader(name, value) }
      set_rack_input(@servlet_env)
      @servlet_env
    end
    
    it "is not lazy by default" do
      env = servlet.create_env filled_servlet_env
      
      env.keys.should include('REQUEST_METHOD')
      env.keys.should include('SCRIPT_NAME')
      env.keys.should include('PATH_INFO')
      env.keys.should include('REQUEST_URI')
      env.keys.should include('QUERY_STRING')
      env.keys.should include('SERVER_NAME')
      env.keys.should include('SERVER_PORT')
      env.keys.should include('REMOTE_HOST')
      env.keys.should include('REMOTE_ADDR')
      env.keys.should include('REMOTE_USER')
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        env.keys.should include(key)
      end
      
      env.keys.should include('rack.version')
      env.keys.should include('rack.input')
      env.keys.should include('rack.errors')
      env.keys.should include('rack.url_scheme')
      env.keys.should include('rack.multithread')
      env.keys.should include('rack.run_once')
      env.keys.should include('java.servlet_context')
      env.keys.should include('java.servlet_request')
      env.keys.should include('java.servlet_response')
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        env.keys.should include(key)
      end
      
      env.keys.should include('HTTP_X_FORWARDED_PROTO')
      env.keys.should include('HTTP_IF_NONE_MATCH')
      env.keys.should include('HTTP_IF_MODIFIED_SINCE')
      env.keys.should include('HTTP_X_SOME_REALLY_LONG_HEADER')
    end
    
    it "works correctly when frozen" do
      env = servlet.create_env filled_servlet_env
      env.freeze
      
      lambda { env['REQUEST_METHOD'] }.should_not raise_error
      lambda { env['SCRIPT_NAME'] }.should_not raise_error
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        lambda { env[key] }.should_not raise_error
        env[key].should_not be nil
      end
      lambda { env['OTHER_METHOD'] }.should_not raise_error
      env['OTHER_METHOD'].should be nil

      lambda { env['rack.version'] }.should_not raise_error
      lambda { env['rack.input'] }.should_not raise_error
      lambda { env['rack.errors'] }.should_not raise_error
      lambda { env['rack.run_once'] }.should_not raise_error
      lambda { env['rack.multithread'] }.should_not raise_error
      lambda { env['java.servlet_context'] }.should_not raise_error
      lambda { env['java.servlet_request'] }.should_not raise_error
      lambda { env['java.servlet_response'] }.should_not raise_error
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        lambda { env[key] }.should_not raise_error
        env[key].should_not be(nil), "key: #{key.inspect} nil"
      end
      lambda { env['rack.whatever'] }.should_not raise_error
      env['rack.whatever'].should be nil
      
      lambda { 
        env['HTTP_X_FORWARDED_PROTO']
        env['HTTP_IF_NONE_MATCH']
        env['HTTP_IF_MODIFIED_SINCE']
        env['HTTP_X_SOME_REALLY_LONG_HEADER']
      }.should_not raise_error
      env['HTTP_X_FORWARDED_PROTO'].should_not be nil
      env['HTTP_IF_NONE_MATCH'].should_not be nil
      env['HTTP_IF_MODIFIED_SINCE'].should_not be nil
      env['HTTP_X_SOME_REALLY_LONG_HEADER'].should_not be nil
      
      lambda { 
        env['HTTP_X_SOME_NON_EXISTENT_HEADER']
      }.should_not raise_error
      env['HTTP_X_SOME_NON_EXISTENT_HEADER'].should be nil
    end
    
    it "works when dupped and frozen as a request" do
      env = servlet.create_env filled_servlet_env
      request = Rack::Request.new(env.dup.freeze)
      
      lambda { request.request_method }.should_not raise_error
      request.request_method.should == 'GET'
      
      lambda { request.script_name }.should_not raise_error
      request.script_name.should == '/main'

      lambda { request.path_info }.should_not raise_error
      request.path_info.should =~ /\/path\/info/

      lambda { request.query_string }.should_not raise_error
      request.query_string.should == 'hello=there'

      lambda { request.content_type }.should_not raise_error
      request.content_type.should == 'text/plain'

      lambda { request.content_length }.should_not raise_error
      request.content_length.should == '4'

      lambda { request.logger }.should_not raise_error
      request.logger.should be nil # we do not setup rack.logger

      lambda { request.scheme }.should_not raise_error
      if Rack.release >= '1.3' # rack 1.3.x 1.4.x
        request.scheme.should == 'https' # X-Forwarded-Proto
      else
        request.scheme.should == 'http' # Rails 3.0 / 2.3
      end

      lambda { request.port }.should_not raise_error
      request.port.should == 80
      
      lambda { request.host_with_port }.should_not raise_error
      request.host_with_port.should == 'serverhost:80'

      lambda { request.referrer }.should_not raise_error
      request.referrer.should == 'http://www.example.com'

      lambda { request.user_agent }.should_not raise_error
      request.user_agent.should == nil
      
      if defined?(request.base_url)
        lambda { request.base_url }.should_not raise_error
        if Rack.release >= '1.3' # Rails >= 3.1.x
          request.base_url.should == 'https://serverhost:80'
        else
          request.base_url.should == 'http://serverhost'
        end
      end

      lambda { request.url }.should_not raise_error
      if Rack.release >= '1.3' # Rails >= 3.1.x
        request.url.should == 'https://serverhost:80/main/app1/path/info?hello=there'
      else
        request.url.should == 'http://serverhost/main/app1/path/info?hello=there'
      end
    end
    
  end
  
  describe 'env (default)' do
    
    it_behaves_like "env"
    
    it_behaves_like "(eager)rack-env"
    
  end

  describe 'lazy env (default)' do
    
    before do
      def servlet.create_env(servlet_env)
        create_lazy_env(servlet_env)
      end
    end
    
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

  describe 'servlet-env' do

    before do
      Rack::Handler::Servlet.env = :servlet
    end
    
    after do
      Rack::Handler::Servlet.env = nil
    end
    
    it_behaves_like "env"
 
    it_behaves_like "(eager)rack-env"
    
    let(:servlet_request) { org.jruby.rack.mock.MockHttpServletRequest.new }
    let(:servlet_response) { org.jruby.rack.mock.MockHttpServletResponse.new }
    let(:servlet_env) do
      org.jruby.rack.servlet.ServletRackEnvironment.new(servlet_request, servlet_response, @rack_context)
    end
    
    it "has correct params when request input has been read" do
      # reproducing https://github.com/jruby/jruby-rack/issues/110
      # 
      # Request Path: /home/path?foo=bad&foo=bar&bar=huu&age=33
      # POST Parameters :
      #  name[]: Ferko Suska
      #  name[]: Jozko Hruska
      #  age: 30
      #  formula: a + b == 42%!
      content = 'name[]=Ferko+Suska&name[]=Jozko+Hruska&age=30&formula=a+%2B+b+%3D%3D+42%25%21'
      servlet_request.setContent content.to_java_bytes
      servlet_request.addHeader('CONTENT-TYPE', 'application/x-www-form-urlencoded')
      servlet_request.setMethod 'POST'
      servlet_request.setContextPath '/home'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'
      servlet_request.setQueryString 'foo=bad&foo=bar&bar=huu&age=33'
      # NOTE: assume input stream read but getParameter methods work correctly :
      # this is essentially the same as some filter/servlet reading before we do
      read_input_stream servlet_request.getInputStream
      # Query params :
      servlet_request.addParameter('foo', 'bad')
      servlet_request.addParameter('foo', 'bar')
      servlet_request.addParameter('bar', 'huu')
      servlet_request.addParameter('age', '33')
      # POST params :
      servlet_request.addParameter('name[]', 'Ferko Suska')
      servlet_request.addParameter('name[]', 'Jozko Hruska')
      servlet_request.addParameter('age', '30')
      servlet_request.addParameter('formula', 'a + b == 42%!')
      
      set_rack_input(servlet_env)

      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)

      rack_request.GET.should == { 'foo'=>'bar', 'bar'=>'huu', 'age'=>'33' }
      rack_request.POST.should == { "name"=>["Ferko Suska", "Jozko Hruska"], "age"=>"30", "formula"=>"a + b == 42%!" }
      rack_request.params.should == {
        "foo"=>"bar", "bar"=>"huu", "age"=>"30", 
        "name"=>["Ferko Suska", "Jozko Hruska"], "formula"=>"a + b == 42%!"
      }

      #request.body.should == nil

      rack_request.query_string.should == 'foo=bad&foo=bar&bar=huu&age=33'
      rack_request.request_method.should == 'POST'
      rack_request.path_info.should == '/path'
      rack_request.script_name.should == '/home' # context path
      rack_request.content_length.should == content.size.to_s
    end

    it "sets cookies from servlet requests" do
      cookies = []
      cookies << javax.servlet.http.Cookie.new('foo', 'bar')
      cookies << javax.servlet.http.Cookie.new('bar', '142')
      servlet_request.setCookies cookies.to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      rack_request.cookies.should == { 'foo' => 'bar', 'bar' => '142' }
    end
    
    it "sets cookies from servlet requests (when empty)" do
      servlet_request.getCookies.should be nil
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      rack_request.cookies.should == {}
      
      servlet_request.setCookies [].to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      rack_request.cookies.should == {}
    end
    
    it "sets a single cookie from servlet requests" do
      cookies = []
      cookies << javax.servlet.http.Cookie.new('foo', 'bar')
      cookies << javax.servlet.http.Cookie.new('foo', '142')
      servlet_request.setCookies cookies.to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      rack_request.cookies.should == { 'foo' => 'bar' }
    end
    
    private

    def read_input_stream(input)
      while input.read != -1
      end
    end
    
  end
  
  private 
  
  def set_rack_input(servlet_env)
    input_class = org.jruby.rack.RackInput.getRackInputClass(JRuby.runtime)
    input = input_class.new(servlet_env.getInputStream)
    servlet_env.set_io input # servlet_env.instance_variable_set :@_io, input
    input
  end
  
end