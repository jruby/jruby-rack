require File.expand_path('../../spec_helper', File.dirname(__FILE__))

require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet do

  class TestRackApp
    def call(env); @_env = env; [ 200, {}, '' ] end
    def _called?; !! @_env end
    def _env; @_env end
  end

  let(:app) { TestRackApp.new }
  let(:servlet) { Rack::Handler::Servlet.new(app) }

  let(:servlet_context) { @servlet_context ||= mock_servlet_context }

  let(:servlet_request) do
    org.jruby.rack.mock.MockHttpServletRequest.new(servlet_context)
  end

  let(:servlet_response) do
    org.jruby.rack.mock.MockHttpServletResponse.new
  end

  shared_examples "env" do

    before do
      @servlet_request ||= servlet_request
      @servlet_response ||= servlet_response
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
      @rack_context.stub(:getServerInfo).and_return 'Trinidad RULEZZ!'

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
      expect( env['java.servlet_request'] ).to be @servlet_request
    end

    it "exposes the servlet response" do
      env = servlet.create_env @servlet_env
      expect( env['java.servlet_response'] ).to be @servlet_response
    end

    it "exposes the servlet context xxxx" do
      env = servlet.create_env @servlet_env
      expect( env['java.servlet_context'] ).to be_a javax.servlet.ServletContext
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
      expect( env['jruby.rack.context'] ).to be @rack_context
    end

    it "retrieves hidden attribute" do
      servlet_request_class = Class.new(org.jruby.rack.mock.MockHttpServletRequest) do

        def getAttributeNames
          names = super.to_a.reject { |name| name.start_with?('org.apache') }
          return java.util.Collections.enumeration(names)
        end

      end
      servlet_request = servlet_request_class.new(servlet_context)
      servlet_request.setAttribute('current_page', 'index.html'.to_java)
      servlet_request.setAttribute('org.answer.internal', 4200.to_java)
      servlet_request.setAttribute('org.apache.internal', true.to_java)

      servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
        servlet_request, servlet_response, @rack_context
      )

      env = servlet.create_env servlet_env

      expect( env.keys ).to include 'current_page'
      expect( env.keys ).to include 'org.answer.internal'
      expect( env.keys ).to_not include 'org.apache.internal'

      expect( env['org.answer.internal'] ).to be 4200
      expect( env['org.apache.internal'] ).to be true
    end

    it "sets attributes with false/null values" do
      @servlet_request.addHeader "Content-Type", "text/plain"
      @servlet_request.setContentType 'text/html'
      @servlet_request.setContent ('0' * 100).to_java_bytes rescue nil # 1.6.8 BUG
      @servlet_request.setAttribute 'org.false', false
      @servlet_request.setAttribute 'null.attr', nil
      @servlet_request.setAttribute 'the.truth', java.lang.Boolean::TRUE

      env = servlet.create_env @servlet_env

      expect( env['org.false'] ).to be false
      expect( env['null.attr'] ).to be nil
      expect( env['the.truth'] ).to be true

      expect( env.keys ).to include 'org.false'
    end

    it "works like a Hash (fetching values)" do
      @servlet_request.addHeader "Content-Type", "text/plain"
      @servlet_request.setContentType 'text/html'

      env = servlet.create_env @servlet_env
      env['attr1'] = 1
      env['attr2'] = false
      env['attr3'] = nil

      expect( env.fetch('attr1', 11) ).to eql 1
      expect( env.fetch('attr2', true) ).to eql false
      expect( env['attr2'] ).to eql false
      expect( env.fetch('attr3', 33) ).to eql nil
      expect( env['attr4'] ).to eql nil
      expect( env.fetch('attr4') { 42 } ).to eql 42
      expect { env.fetch('attr4') }.to raise_error # KeyError
    end

    it "parses strange request parameters (Rack-compat)" do
      servlet_request = @servlet_request
      servlet_request.setMethod 'GET'
      servlet_request.setContextPath '/'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'

      servlet_request.setQueryString 'foo]=0&bar[=1&baz_=2&[meh=3'
      servlet_request.addParameter('foo]', '0')
      servlet_request.addParameter('bar[', '1')
      servlet_request.addParameter('baz_', '2')
      servlet_request.addParameter('[meh', '3')

      env = servlet.create_env(@servlet_env)
      rack_request = Rack::Request.new(env)

      # Rack (1.5.2) does it as :
      # { "foo" => "0", "bar" => nil, "baz_" => "2", "meh" => "3" }
      # 1.6.0 :
      # { "foo" => "0", "bar[" => "1", "baz_" => "2", "meh" => "3" }

      expect( rack_request.GET['foo'] ).to eql('0')
      expect( rack_request.GET['baz_'] ).to eql('2')

      if rack_release('1.6')
        # expect( rack_request.GET['bar['] ).to eql('1')
      else
        expect( rack_request.GET.key?('bar') ).to be true
      end
      expect( rack_request.GET['meh'] ).to eql('3')

      expect( rack_request.query_string ).to eql 'foo]=0&bar[=1&baz_=2&[meh=3'
    end

    it "parses nestedx request parameters (Rack-compat)" do
      servlet_request = @servlet_request
      servlet_request.setMethod 'GET'
      servlet_request.setContextPath '/'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'

      servlet_request.setQueryString 'foo[bar]=0&foo[baz]=1&foo[bar]=2&foo[meh[]]=x&foo[meh[]]=42&huh[1]=b&huh[0]=a'
      servlet_request.addParameter('foo[bar]', '0')
      servlet_request.addParameter('foo[baz]', '1')
      servlet_request.addParameter('foo[bar]', '2')
      servlet_request.addParameter('foo[meh[]]', 'x')
      servlet_request.addParameter('foo[meh[]]', '42')
      servlet_request.addParameter('huh[1]', 'b')
      servlet_request.addParameter('huh[0]', 'a')

      env = servlet.create_env(@servlet_env)
      rack_request = Rack::Request.new(env)

      #params = { "foo" => { "bar" => "2", "baz" => "1", "meh" => [ nil, nil ] }, "huh" => { "1" => "b", "0" => "a" } }
      #expect( rack_request.GET ).to eql(params)

      expect( rack_request.GET['foo']['bar'] ).to eql('2')
      expect( rack_request.GET['foo']['baz'] ).to eql('1')
      expect( rack_request.params['foo']['meh'] ).to be_a Array
      expect( rack_request.params['huh'] ).to eql({ "1" => "b", "0" => "a" })

      expect( rack_request.POST ).to eql Hash.new

      expect( rack_request.query_string ).to eql 'foo[bar]=0&foo[baz]=1&foo[bar]=2&foo[meh[]]=x&foo[meh[]]=42&huh[1]=b&huh[0]=a'
    end

    it "raises if nested request parameters are broken (Rack-compat)" do
      servlet_request = @servlet_request
      servlet_request.setMethod 'GET'
      servlet_request.setContextPath '/'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'
      servlet_request.setQueryString 'foo[]=0&foo[bar]=1'
      servlet_request.addParameter('foo[]', '0')
      servlet_request.addParameter('foo[bar]', '1')

      env = servlet.create_env(@servlet_env)
      rack_request = Rack::Request.new(env)

      # Rack::Utils::ParameterTypeError (< TypeError) since 1.6.0
      if Rack::Utils.const_defined? :ParameterTypeError
        error = Rack::Utils::ParameterTypeError
      else
        error = TypeError
      end

      expect { rack_request.GET }.to raise_error(error, "expected Hash (got Array) for param `foo'")
      rack_request.POST.should == {}
      expect { rack_request.params }.to raise_error(error, "expected Hash (got Array) for param `foo'") if rack_release('1.6')

      rack_request.query_string.should == 'foo[]=0&foo[bar]=1'
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
      @rack_context.stub(:getServerInfo).and_return 'Trinidad'
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
      @servlet_env
    end

    it "is a Hash" do
      env = servlet.create_env filled_servlet_env
      expect( env ).to be_a Hash
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

      expect { env['REQUEST_METHOD'] }.to_not raise_error
      expect { env['SCRIPT_NAME'] }.to_not raise_error
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        expect { env[key] }.to_not raise_error
        env[key].should_not be nil
      end
      expect { env['OTHER_METHOD'] }.to_not raise_error
      env['OTHER_METHOD'].should be nil

      expect { env['rack.version'] }.to_not raise_error
      expect { env['rack.input'] }.to_not raise_error
      expect { env['rack.errors'] }.to_not raise_error
      expect { env['rack.run_once'] }.to_not raise_error
      expect { env['rack.multithread'] }.to_not raise_error
      expect { env['java.servlet_context'] }.to_not raise_error
      expect { env['java.servlet_request'] }.to_not raise_error
      expect { env['java.servlet_response'] }.to_not raise_error
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        lambda { env[key] }.should_not raise_error
        env[key].should_not be(nil), "key: #{key.inspect} nil"
      end
      expect { env['rack.whatever'] }.to_not raise_error
      env['rack.whatever'].should be nil

      expect {
        env['HTTP_X_FORWARDED_PROTO']
        env['HTTP_IF_NONE_MATCH']
        env['HTTP_IF_MODIFIED_SINCE']
        env['HTTP_X_SOME_REALLY_LONG_HEADER']
      }.to_not raise_error
      env['HTTP_X_FORWARDED_PROTO'].should_not be nil
      env['HTTP_IF_NONE_MATCH'].should_not be nil
      env['HTTP_IF_MODIFIED_SINCE'].should_not be nil
      env['HTTP_X_SOME_REALLY_LONG_HEADER'].should_not be nil

      expect { env['HTTP_X_SOME_NON_EXISTENT_HEADER'] }.to_not raise_error
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

    describe 'dumped-and-loaded' do

      before { @context = JRuby::Rack.context; JRuby::Rack.context = nil }
      after { JRuby::Rack.context = @context }

      it "is a DefaultEnv" do
        env = servlet.create_env filled_servlet_env
        dump = Marshal.dump( env.to_hash ); env = Marshal.load(dump)
        expect( env ).to be_a Rack::Handler::Servlet::DefaultEnv
      end

      it "works (almost) as before" do
        env = servlet.create_env filled_servlet_env
        dump = Marshal.dump( env.to_hash )
        it_works env = Marshal.load(dump)

        expect( env['rack.input'] ).to be nil
        expect( env['rack.errors'] ).to be nil

        expect( env['java.servlet_context'] ).to be nil
        expect( env['java.servlet_request'] ).to be nil
        expect( env['java.servlet_response'] ).to be nil
      end

      it "initialized than dumped" do
        env = servlet.create_env filled_servlet_env
        it_works env

        expect( env['rack.input'] ).to_not be nil
        expect( env['rack.errors'] ).to_not be nil

        expect( env['java.servlet_context'] ).to_not be nil
        expect( env['java.servlet_request'] ).to_not be nil
        expect( env['java.servlet_response'] ).to_not be nil

        dump = Marshal.dump( env.to_hash )
        it_works env = Marshal.load(dump)

        expect( env['rack.input'] ).to be nil
        expect( env['rack.errors'] ).to be nil

        expect( env['java.servlet_context'] ).to be nil
        expect( env['java.servlet_request'] ).to be nil
        expect( env['java.servlet_response'] ).to be nil
      end

      def it_works(env)
        expect( env['REQUEST_METHOD'] ).to eql 'GET'
        expect( env['SCRIPT_NAME'] ).to eql '/main'
        expect( env['SERVER_NAME'] ).to eql 'serverhost'
        expect( env['SERVER_PORT'] ).to eql '80'
        expect( env['OTHER_METHOD'] ).to be nil
        Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
          expect( env[key] ).to_not be(nil), "key: #{key.inspect} nil"
        end

        expect( env['rack.url_scheme'] ).to_not be nil
        expect( env['rack.version'] ).to_not be nil
        expect( env['jruby.rack.version'] ).to_not be nil

        expect( env['rack.run_once'] ).to be false
        expect( env['rack.multithread'] ).to be true

        expect( env['rack.whatever'] ).to be nil

        expect( env['HTTP_REFERER'] ).to eql 'http://www.example.com'
        expect( env['HTTP_X_FORWARDED_PROTO'] ).to_not be nil
        expect( env['HTTP_IF_NONE_MATCH'] ).to_not be nil
        expect( env['HTTP_IF_MODIFIED_SINCE'] ).to_not be nil
        expect( env['HTTP_X_SOME_REALLY_LONG_HEADER'] ).to_not be nil
        expect( env['HTTP_X_SOME_NON_EXISTENT_HEADER'] ).to be nil
      end

    end

  end

  shared_examples "hash-instance" do

    before do
      @servlet_request ||= servlet_request
      @servlet_response ||= servlet_response
      @servlet_env ||= org.jruby.rack.servlet.ServletRackEnvironment.new(
        @servlet_request, @servlet_response, @rack_context
      )
    end

    it "creates a new Hash" do
      hash = new_hash
      expect( hash ).to be_a Hash
    end

    it "a new Hash is empty" do
      hash = new_hash
      expect( hash ).to be_empty
    end

    it "allows filling a new Hash" do
      hash = new_hash
      hash['some'] = 'SOME'
      expect( hash['some'] ).to eql 'SOME'
    end

    it "allows iterating over a new Hash" do
      hash = new_hash
      hash['some'] = 'SOME'
      hash['more'] =[ 'MORE' ]
      expect( hash.keys.size ).to be 2
      expect( hash.values.size ).to be 2
      hash.each do |key, val|
        case key
        when 'some' then expect( val ).to eql 'SOME'
        when 'more' then expect( val ).to eql [ 'MORE' ]
        else fail("unexpected #{key.inspect} = #{val.inspect}")
        end
      end
    end

    it "sets all keys from the env Hash" do
      env = servlet.create_env(@servlet_env)
      hash = env.class.new
      env.keys.each { |k| hash[k] = env[k] if env.has_key?(k) }
      expect( hash.size ).to eql env.size
    end

    private

    def new_hash
      hash = servlet.create_env(@servlet_env)
      hash.class.new
    end

  end

  describe '(default) env' do

    it_behaves_like "env"

    it_behaves_like "(eager)rack-env"

    it_behaves_like "hash-instance"

  end

  describe 'lazy env' do

    before do
      def servlet.create_env(servlet_env)
        Rack::Handler::Servlet::DefaultEnv.new(servlet_env)
      end
    end

    it_behaves_like "env"

    let(:filled_servlet_env) do
      servlet_request.setMethod('GET')
      servlet_request.setContextPath('/main')
      servlet_request.setServletPath('/app1')
      servlet_request.setPathInfo('/path/info')
      servlet_request.setRequestURI('/main/app1/path/info')
      servlet_request.setQueryString('hello=there')
      servlet_request.setServerName('serverhost')
      servlet_request.setServerPort(80)
      @rack_context.stub(:getServerInfo).and_return 'Trinidad'
      servlet_request.setRemoteAddr('127.0.0.1')
      servlet_request.setRemoteHost('localhost')
      servlet_request.setRemoteUser('admin')
      servlet_request.setContentType('text/plain')
      servlet_request.setContent('1234'.to_java_bytes) # Content-Length
      { "X-Forwarded-Proto" => "https",
        "If-None-Match" => "03273f2f207cb7864f217458f0f85e4e",
        "If-Modified-Since" => "Sun, Aug 19 2012 12:11:50 +0200",
        "Referer" => "http://www.example.com",
        "X-Some-Really-Long-Header" => "42"
      }.each { |name, value| servlet_request.addHeader(name, value) }

      servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
        servlet_request, servlet_response, @rack_context
      )
      servlet_env
    end

    it "populates on keys" do
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

      expect( env['java.servlet_context'] ).to_not be nil
      if servlet_30?
        expect( env['java.servlet_context'] ).to be @servlet_context
      else
        expect( env['java.servlet_context'] ).to be @rack_context

        # HACK to emulate Servlet API 3.0 MockHttpServletRequest has getServletContext :
        env = Rack::Handler::Servlet::DefaultEnv.new(@servlet_request).to_hash

        expect( env['java.servlet_context'] ).to_not be nil
        expect( env['java.servlet_context'] ).to be @servlet_context
        begin
          env['java.servlet_context'].should == @servlet_context
        rescue NoMethodError
          (env['java.servlet_context'] == @servlet_context).should == true
        end
      end
    end

    it "returns the servlet request when queried with java.servlet_request" do
      env = servlet.create_env @servlet_env
      expect( env['java.servlet_request'] ).to be @servlet_request
    end

    it "returns the servlet response when queried with java.servlet_response" do
      env = servlet.create_env @servlet_env
      expect( env['java.servlet_response'] ).to be @servlet_response
    end

  end

  describe "call" do

    it "delegates to the inner application after constructing the env hash" do
      servlet.should_receive(:create_env).and_return({})
      servlet_env = double("servlet request")

      response = servlet.call(servlet_env)
      expect( response.to_java ).to respond_to(:respond) # RackResponse

      expect( app._called? ).to be true
    end

    it "raises an error when it failed to load the application" do
      expect { Rack::Handler::Servlet.new(nil) }.to raise_error(ArgumentError)
    end

  end

  describe 'response' do

    before do
      Rack::Handler::Servlet.response = 'Rack::Handler::CustomResponse'
    end

    after do
      Rack::Handler::Servlet.response = nil
    end

    it "uses custom response class" do
      servlet.should_receive(:create_env).and_return({})
      #app.should_receive(:call).and_return([ 200, {}, '' ])

      servlet_env = double("servlet request")
      expect( servlet.call(servlet_env) ).to be_a Rack::Handler::CustomResponse
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

    it_behaves_like "hash-instance"

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

    it "handles null values in parameter-map (Jetty)" do
      org.jruby.rack.mock.MockHttpServletRequest.class_eval do
        field_reader :parameters
      end
      # reproducing https://github.com/jruby/jruby-rack/issues/154
      #
      # Request Path: /home/path?foo=bad&foo=bar&bar=huu&age=33
      # POST Parameters :
      #  name[]: Ferko Suska
      #  name[]: Jozko Hruska
      #  age: 42
      content = 'name[]=ferko&name[]=jozko&age=42'

      servlet_request.setContent content.to_java_bytes
      servlet_request.addHeader('CONTENT-TYPE', 'application/x-www-form-urlencoded')
      servlet_request.setMethod 'PUT'
      servlet_request.setContextPath '/'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'
      servlet_request.setQueryString 'foo=bar&foo=huu&bar=&age='
      # NOTE: assume input stream read but getParameter methods work correctly :
      # this is essentially the same as some filter/servlet reading before we do
      read_input_stream servlet_request.getInputStream
      # Query params :
      servlet_request.addParameter('foo', 'bar')
      servlet_request.addParameter('foo', 'huu')
      servlet_request.parameters.put('bar', nil) # "emulate" buggy servlet container
      servlet_request.parameters.put('age', [ nil ].to_java(:string)) # buggy container
      # POST params :
      servlet_request.addParameter('name[]', 'ferko')
      servlet_request.addParameter('name[]', 'jozko')

      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)

      rack_request.GET.should == { 'foo'=>'huu', 'bar'=>'', 'age'=>'' }
      rack_request.POST.should == { "name"=>["ferko", "jozko"] }
      rack_request.params.should == {
        "foo"=>"huu", "bar"=>"", "age"=>"", "name"=>["ferko", "jozko"],
      }

      rack_request.query_string.should == 'foo=bar&foo=huu&bar=&age='
      rack_request.request_method.should == 'PUT'
    end

    it "does not truncate query strings containing semi-colons (Rack-compat)" do
      servlet_request.setMethod 'GET'
      servlet_request.setContextPath '/'
      servlet_request.setPathInfo '/path'
      servlet_request.setRequestURI '/home/path'
      servlet_request.setQueryString 'foo=bar&quux=b;la'
      # Query params :
      servlet_request.addParameter('foo', 'bar')
      servlet_request.addParameter('quux', 'b;la')

      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)

      rack_request.GET.should == { "foo" => "bar", "quux" => "b;la" }
      rack_request.POST.should == {}
      rack_request.params.should == { "foo" => "bar", "quux" => "b;la" }

      rack_request.query_string.should == 'foo=bar&quux=b;la'
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

end