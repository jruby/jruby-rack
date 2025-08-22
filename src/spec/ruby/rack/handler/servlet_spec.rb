require File.expand_path('../../spec_helper', File.dirname(__FILE__))

require 'rack/handler/servlet'
require 'stringio'

describe Rack::Handler::Servlet do

  class TestRackApp
    def call(env)
      ; @_env = env; [200, {}, '']
    end

    def _called?
      !!@_env
    end

    def _env
      @_env
    end
  end

  let(:app) { TestRackApp.new }
  let(:servlet) { Rack::Handler::Servlet.new(app) }

  let(:servlet_context) { @servlet_context ||= mock_servlet_context }

  let(:servlet_request) do
    org.springframework.mock.web.MockHttpServletRequest.new(servlet_context)
  end

  let(:servlet_response) do
    org.springframework.mock.web.MockHttpServletResponse.new
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
      expect(hash['rack.version']).to eq Rack::VERSION
      expect(hash['rack.multithread']).to eq true
      expect(hash['rack.multiprocess']).to eq false
      expect(hash['rack.run_once']).to eq false
    end

    it "adds all attributes from the servlet request" do
      @servlet_request.setAttribute("PATH_INFO", "/path/info")
      @servlet_request.setAttribute("custom.attribute", true)

      env = servlet.create_env @servlet_env
      expect(env["PATH_INFO"]).to eq "/path/info"
      expect(env["custom.attribute"]).to eq true
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
      allow(@rack_context).to receive(:getServerInfo).and_return 'Trinidad RULEZZ!'

      env = servlet.create_env @servlet_env
      expect(env["REQUEST_METHOD"]).to eq "POST"
      expect(env["SCRIPT_NAME"]).to eq "/override"
      expect(env["PATH_INFO"]).to eq "/override"
      expect(env["REQUEST_URI"]).to eq "/override"
      expect(env["QUERY_STRING"]).to eq "override"
      expect(env["SERVER_NAME"]).to eq "override"
      expect(env["SERVER_PORT"]).to eq "8080"
      expect(env["SERVER_SOFTWARE"]).to eq "servy"
      expect(env["REMOTE_HOST"]).to eq "override"
      expect(env["REMOTE_ADDR"]).to eq "192.168.0.1"
      expect(env["REMOTE_USER"]).to eq "override"
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
      expect(env["CONTENT_TYPE"]).to eq "application/override"
      expect(env["CONTENT_LENGTH"]).to eq "20"
      expect(env["HTTP_HOST"]).to eq "override"
      expect(env["HTTP_ACCEPT"]).to eq "application/*"
      expect(env["HTTP_ACCEPT_ENCODING"]).to eq "bzip2"
    end

    it "is not able to override CONTENT_TYPE or CONTENT_LENGTH to nil" do
      attrs = { "CONTENT_TYPE" => nil, "CONTENT_LENGTH" => -1 }
      attrs.each { |name, value| @servlet_request.setAttribute(name, value) }
      @servlet_request.setContentType('text/html')
      @servlet_request.setContent('1234567890'.to_java_bytes)

      env = servlet.create_env @servlet_env
      expect(env["CONTENT_TYPE"]).to eq "text/html"
      expect(env["CONTENT_LENGTH"]).to eq "10"
    end

    it "sets the rack.input and rack.errors keys" do
      @servlet_request.setScheme('http')
      @servlet_request.setContextPath('/foo')
      @servlet_request.setContent(''.to_java_bytes)

      env = servlet.create_env @servlet_env

      expect((input = env['rack.input'])).not_to be nil
      [:gets, :read, :each].each { |sym| expect(input.respond_to?(sym)).to eq true }
      expect((errors = env['rack.errors'])).not_to be nil
      [:puts, :write, :flush].each { |sym| expect(errors.respond_to?(sym)).to eq true }
    end

    it "sets the rack.errors to log via rack context" do
      env = servlet.create_env @servlet_env
      expect(env['rack.errors']).to be_a(JRuby::Rack::ServletLog)

      expect(@rack_context).to receive(:log).with("bar").ordered
      expect(@rack_context).to receive(:log).with("huu").ordered

      env['rack.errors'].puts "bar"
      env['rack.errors'].write "huu"
    end

    it "sets env['HTTPS'] = 'on' if scheme is https" do
      @servlet_request.setScheme('https')

      env = servlet.create_env @servlet_env

      env['rack.url_scheme']
      expect(env['HTTPS']).to eq 'on'
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

      expect(env["REQUEST_METHOD"]).to eq "GET"
      expect(env["SCRIPT_NAME"]).to eq "/app"
      expect(env["PATH_INFO"]).to eq "/script_name/path/info"
      expect(env["REQUEST_URI"]).to eq "/app/script_name/path/info?hello=there"
      expect(env["QUERY_STRING"]).to eq "hello=there"
      expect(env["SERVER_NAME"]).to eq "serverhost"
      expect(env["SERVER_PORT"]).to eq "80"
      expect(env["REMOTE_HOST"]).to eq "localhost"
      expect(env["REMOTE_ADDR"]).to eq "127.0.0.1"
      expect(env["REMOTE_USER"]).to eq "admin"
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

      { "Host" => "serverhost",
        "Accept" => "text/*",
        "Accept-Encoding" => "gzip" }.each do |name, value|
        @servlet_request.addHeader(name, value)
      end

      env = servlet.create_env @servlet_env
      expect(env["rack.version"]).to eq Rack::VERSION
      expect(env["CONTENT_TYPE"]).to eq "text/html"
      expect(env["HTTP_HOST"]).to eq "serverhost"
      expect(env["HTTP_ACCEPT"]).to eq "text/*"
      expect(env["REQUEST_METHOD"]).to eq "GET"
      expect(env["SCRIPT_NAME"]).to eq "/app"
      expect(env["PATH_INFO"]).to eq "/script_name/path/info"
      expect(env["REQUEST_URI"]).to eq "/app/script_name/path/info?hello=there"
      expect(env["QUERY_STRING"]).to eq "hello=there"
      expect(env["SERVER_NAME"]).to eq "serverhost"
      expect(env["SERVER_PORT"]).to eq "80"
      expect(env["REMOTE_HOST"]).to eq "localhost"
      expect(env["REMOTE_ADDR"]).to eq "127.0.0.1"
      expect(env["REMOTE_USER"]).to eq "admin"
    end

    it "sets environment variables to the empty string if their value is nil" do
      @servlet_request.setMethod(nil) # by default it's ''
      @servlet_request.setServerName(nil) # default 'localhost'
      @servlet_request.setRemoteHost(nil) # default 'localhost'
      @servlet_request.setRemoteAddr(nil) # default '127.0.0.1'

      env = servlet.create_env @servlet_env
      expect(env["REQUEST_METHOD"]).to eq "GET"
      expect(env["SCRIPT_NAME"]).to eq ""
      expect(env["PATH_INFO"]).to eq ""
      expect(env["REQUEST_URI"]).to eq ""
      expect(env["QUERY_STRING"]).to eq ""
      expect(env["SERVER_NAME"]).to eq ""
      expect(env["REMOTE_HOST"]).to eq ""
      expect(env["REMOTE_ADDR"]).to eq ""
      expect(env["REMOTE_USER"]).to eq ""
    end

    it "calculates path info from the servlet path and the path info" do
      @servlet_request.setContextPath('/context')
      @servlet_request.setServletPath('/path')

      env = servlet.create_env @servlet_env
      expect(env["SCRIPT_NAME"]).to eq "/context"
      expect(env["PATH_INFO"]).to eq "/path"
    end

    it "works correctly when running under the root context" do
      @servlet_request.setContextPath('')
      @servlet_request.setServletPath('/')

      env = servlet.create_env @servlet_env
      expect(env["PATH_INFO"]).to eq "/"
      expect(env["SCRIPT_NAME"]).to eq ""
    end

    it "ignores servlet path when it is not part of the request URI" do
      # This craziness is what happens in the default Tomcat 7 install
      @servlet_request.setContextPath('/context')
      @servlet_request.setServletPath('/index.jsp')
      @servlet_request.setRequestURI('/context/')

      env = servlet.create_env @servlet_env
      expect(env["SCRIPT_NAME"]).to eq "/context"
      expect(env["PATH_INFO"]).to eq "/"
    end

    it "includes query string in the request URI" do
      @servlet_request.setRequestURI('/some/path')
      @servlet_request.setQueryString('some=query&string')

      env = servlet.create_env @servlet_env
      expect(env["REQUEST_URI"]).to eq "/some/path?some=query&string"
    end

    it "puts content type and content length in the hash without the HTTP_ prefix" do
      @servlet_request.addHeader("Content-Type", "text/plain")
      @servlet_request.setContentType('text/html')
      @servlet_request.setContent('0123456789'.to_java_bytes) # length 10

      env = servlet.create_env @servlet_env
      expect(env["CONTENT_TYPE"]).to eq "text/html"
      expect(env["CONTENT_LENGTH"]).to eq "10"
      expect(env["HTTP_CONTENT_TYPE"]).to eq nil
      expect(env).not_to have_key("HTTP_CONTENT_TYPE")
      expect(env["HTTP_CONTENT_LENGTH"]).to eq nil
      expect(env).not_to have_key("HTTP_CONTENT_LENGTH")
    end

    it "puts the other headers in the hash upcased and underscored and prefixed with HTTP_" do
      { "Host" => "localhost",
        "Accept" => "text/*",
        "Accept-Encoding" => "gzip",
        "Content-Length" => "0"
      }.each { |name, value| @servlet_request.addHeader(name, value) }

      env = servlet.create_env @servlet_env
      expect(env["CONTENT_TYPE"]).to eq nil
      expect(env).not_to have_key("CONTENT_TYPE")
      expect(env["CONTENT_LENGTH"]).to eq nil
      expect(env).not_to have_key("CONTENT_LENGTH")
      expect(env["HTTP_HOST"]).to eq "localhost"
      expect(env["HTTP_ACCEPT"]).to eq "text/*"
      expect(env["HTTP_ACCEPT_ENCODING"]).to eq "gzip"
    end

    it "handles header names that have more than one dash in them" do
      { "X-Forwarded-Proto" => "https",
        "If-None-Match" => "abcdef",
        "If-Modified-Since" => "today",
        "X-Some-Really-Long-Header" => "yeap"
      }.each { |name, value| @servlet_request.addHeader(name, value) }

      env = servlet.create_env @servlet_env
      expect(env["HTTP_X_FORWARDED_PROTO"]).to eq "https"
      expect(env["HTTP_IF_NONE_MATCH"]).to eq "abcdef"
      expect(env["HTTP_IF_MODIFIED_SINCE"]).to eq "today"
      expect(env["HTTP_X_SOME_REALLY_LONG_HEADER"]).to eq "yeap"
    end

    it "exposes the servlet request" do
      env = servlet.create_env @servlet_env
      expect(env['java.servlet_request']).to be @servlet_request
    end

    it "exposes the servlet response" do
      env = servlet.create_env @servlet_env
      expect(env['java.servlet_response']).to be @servlet_response
    end

    it "exposes the servlet context xxxx" do
      env = servlet.create_env @servlet_env
      expect(env['java.servlet_context']).to be_a javax.servlet.ServletContext
    end

    it "exposes the rack context" do
      env = servlet.create_env @servlet_env
      expect(env['jruby.rack.context']).to be @rack_context
    end

    it "retrieves hidden attribute" do
      servlet_request_class = Class.new(org.springframework.mock.web.MockHttpServletRequest) do

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

      expect(env.keys).to include 'current_page'
      expect(env.keys).to include 'org.answer.internal'
      expect(env.keys).to_not include 'org.apache.internal'

      expect(env['org.answer.internal']).to be 4200
      expect(env['org.apache.internal']).to be true
    end

    it "sets attributes with false/null values" do
      @servlet_request.addHeader "Content-Type", "text/plain"
      @servlet_request.setContentType 'text/html'
      @servlet_request.setContent ('0' * 100).to_java_bytes
      @servlet_request.setAttribute 'org.false', false
      @servlet_request.setAttribute 'null.attr', nil
      @servlet_request.setAttribute 'the.truth', java.lang.Boolean::TRUE

      env = servlet.create_env @servlet_env

      expect(env['org.false']).to be false
      expect(env['null.attr']).to be nil
      expect(env['the.truth']).to be true

      expect(env.keys).to include 'org.false'
    end

    it "works like a Hash (fetching values)" do
      @servlet_request.addHeader "Content-Type", "text/plain"
      @servlet_request.setContentType 'text/html'

      env = servlet.create_env @servlet_env
      env['attr1'] = 1
      env['attr2'] = false
      env['attr3'] = nil

      expect(env.fetch('attr1', 11)).to eql 1
      expect(env.fetch('attr2', true)).to eql false
      expect(env['attr2']).to eql false
      expect(env.fetch('attr3', 33)).to eql nil
      expect(env['attr4']).to eql nil
      expect(env.fetch('attr4') { 42 }).to eql 42
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

      # { "foo" => "0", "bar[" => "1", "baz_" => "2", "meh" => "3" }

      expect(rack_request.GET['foo']).to eql('0')
      expect(rack_request.GET['baz_']).to eql('2')
      expect(rack_request.GET['meh']).to eql('3')

      expect(rack_request.query_string).to eql 'foo]=0&bar[=1&baz_=2&[meh=3'
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

      # params = { "foo" => { "bar" => "2", "baz" => "1", "meh" => [ nil, nil ] }, "huh" => { "1" => "b", "0" => "a" } }
      #    expect(rack_request.GET).to eql(params)

      expect(rack_request.GET['foo']['bar']).to eql('2')
      expect(rack_request.GET['foo']['baz']).to eql('1')
      expect(rack_request.params['foo']['meh']).to be_a Array
      expect(rack_request.params['huh']).to eql({ "1" => "b", "0" => "a" })

      expect(rack_request.POST).to eql Hash.new

      expect(rack_request.query_string).to eql 'foo[bar]=0&foo[baz]=1&foo[bar]=2&foo[meh[]]=x&foo[meh[]]=42&huh[1]=b&huh[0]=a'
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
      expect(rack_request.POST).to eq({})
      expect { rack_request.params }.to raise_error(error, "expected Hash (got Array) for param `foo'")

      expect(rack_request.query_string).to eq 'foo[]=0&foo[bar]=1'
    end

  end

  shared_examples "(eager)rack-env" do

    before do
      @servlet_request = org.springframework.mock.web.MockHttpServletRequest.new(@servlet_context)
      @servlet_response = org.springframework.mock.web.MockHttpServletResponse.new
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
      allow(@rack_context).to receive(:getServerInfo).and_return 'Trinidad'
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
      expect(env).to be_a Hash
    end

    it "is not lazy by default" do
      env = servlet.create_env filled_servlet_env

      expect(env.keys).to include('REQUEST_METHOD')
      expect(env.keys).to include('SCRIPT_NAME')
      expect(env.keys).to include('PATH_INFO')
      expect(env.keys).to include('REQUEST_URI')
      expect(env.keys).to include('QUERY_STRING')
      expect(env.keys).to include('SERVER_NAME')
      expect(env.keys).to include('SERVER_PORT')
      expect(env.keys).to include('REMOTE_HOST')
      expect(env.keys).to include('REMOTE_ADDR')
      expect(env.keys).to include('REMOTE_USER')
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        expect(env.keys).to include(key)
      end

      expect(env.keys).to include('rack.version')
      expect(env.keys).to include('rack.input')
      expect(env.keys).to include('rack.errors')
      expect(env.keys).to include('rack.url_scheme')
      expect(env.keys).to include('rack.multithread')
      expect(env.keys).to include('rack.run_once')
      expect(env.keys).to include('java.servlet_context')
      expect(env.keys).to include('java.servlet_request')
      expect(env.keys).to include('java.servlet_response')
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        expect(env.keys).to include(key)
      end

      expect(env.keys).to include('HTTP_X_FORWARDED_PROTO')
      expect(env.keys).to include('HTTP_IF_NONE_MATCH')
      expect(env.keys).to include('HTTP_IF_MODIFIED_SINCE')
      expect(env.keys).to include('HTTP_X_SOME_REALLY_LONG_HEADER')
    end

    it "works correctly when frozen" do
      env = servlet.create_env filled_servlet_env
      env.freeze

      expect { env['REQUEST_METHOD'] }.to_not raise_error
      expect { env['SCRIPT_NAME'] }.to_not raise_error
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        expect { env[key] }.to_not raise_error
        expect(env[key]).not_to be nil
      end
      expect { env['OTHER_METHOD'] }.to_not raise_error
      expect(env['OTHER_METHOD']).to be nil

      expect { env['rack.version'] }.to_not raise_error
      expect { env['rack.input'] }.to_not raise_error
      expect { env['rack.errors'] }.to_not raise_error
      expect { env['rack.run_once'] }.to_not raise_error
      expect { env['rack.multithread'] }.to_not raise_error
      expect { env['java.servlet_context'] }.to_not raise_error
      expect { env['java.servlet_request'] }.to_not raise_error
      expect { env['java.servlet_response'] }.to_not raise_error
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        expect { env[key] }.not_to raise_error
        expect(env[key]).not_to be(nil), "key: #{key.inspect} nil"
      end
      expect { env['rack.whatever'] }.to_not raise_error
      expect(env['rack.whatever']).to be nil

      expect {
        env['HTTP_X_FORWARDED_PROTO']
        env['HTTP_IF_NONE_MATCH']
        env['HTTP_IF_MODIFIED_SINCE']
        env['HTTP_X_SOME_REALLY_LONG_HEADER']
      }.to_not raise_error
      expect(env['HTTP_X_FORWARDED_PROTO']).not_to be nil
      expect(env['HTTP_IF_NONE_MATCH']).not_to be nil
      expect(env['HTTP_IF_MODIFIED_SINCE']).not_to be nil
      expect(env['HTTP_X_SOME_REALLY_LONG_HEADER']).not_to be nil

      expect { env['HTTP_X_SOME_NON_EXISTENT_HEADER'] }.to_not raise_error
      expect(env['HTTP_X_SOME_NON_EXISTENT_HEADER']).to be nil
    end

    it "works when dupped and frozen as a request" do
      env = servlet.create_env filled_servlet_env
      request = Rack::Request.new(env.dup.freeze)

      expect { request.request_method }.not_to raise_error
      expect(request.request_method).to eq 'GET'

      expect { request.script_name }.not_to raise_error
      expect(request.script_name).to eq '/main'

      expect { request.path_info }.not_to raise_error
      expect(request.path_info).to match(/\/path\/info/)

      expect { request.query_string }.not_to raise_error
      expect(request.query_string).to eq 'hello=there'

      expect { request.content_type }.not_to raise_error
      expect(request.content_type).to eq 'text/plain'

      expect { request.content_length }.not_to raise_error
      expect(request.content_length).to eq '4'

      expect { request.logger }.not_to raise_error
      expect(request.logger).to be nil # we do not setup rack.logger

      expect { request.scheme }.not_to raise_error
      expect(request.scheme).to eq 'https' # X-Forwarded-Proto

      expect { request.port }.not_to raise_error
      expect(request.port).to eq 80

      expect { request.host_with_port }.not_to raise_error
      expect(request.host_with_port).to eq 'serverhost:80'

      expect { request.referrer }.not_to raise_error
      expect(request.referrer).to eq 'http://www.example.com'

      expect { request.user_agent }.not_to raise_error
      expect(request.user_agent).to eq nil

      if defined?(request.base_url)
        expect { request.base_url }.not_to raise_error
        expect(request.base_url).to eq 'https://serverhost:80'
      end

      expect { request.url }.not_to raise_error
      expect(request.url).to eq 'https://serverhost:80/main/app1/path/info?hello=there'
    end

    describe 'dumped-and-loaded' do

      before { @context = JRuby::Rack.context; JRuby::Rack.context = nil }
      after { JRuby::Rack.context = @context }

      it "is a DefaultEnv" do
        env = servlet.create_env filled_servlet_env
        dump = Marshal.dump(env.to_hash); env = Marshal.load(dump)
        expect(env).to be_a Rack::Handler::Servlet::DefaultEnv
      end

      it "works (almost) as before" do
        env = servlet.create_env filled_servlet_env
        dump = Marshal.dump(env.to_hash)
        it_works env = Marshal.load(dump)

        expect(env['rack.input']).to be nil
        expect(env['rack.errors']).to be nil

        expect(env['java.servlet_context']).to be nil
        expect(env['java.servlet_request']).to be nil
        expect(env['java.servlet_response']).to be nil
      end

      it "initialized than dumped" do
        env = servlet.create_env filled_servlet_env
        it_works env

        expect(env['rack.input']).to_not be nil
        expect(env['rack.errors']).to_not be nil

        expect(env['java.servlet_context']).to_not be nil
        expect(env['java.servlet_request']).to_not be nil
        expect(env['java.servlet_response']).to_not be nil

        dump = Marshal.dump(env.to_hash)
        it_works env = Marshal.load(dump)

        expect(env['rack.input']).to be nil
        expect(env['rack.errors']).to be nil

        expect(env['java.servlet_context']).to be nil
        expect(env['java.servlet_request']).to be nil
        expect(env['java.servlet_response']).to be nil
      end

      def it_works(env)
        expect(env['REQUEST_METHOD']).to eql 'GET'
        expect(env['SCRIPT_NAME']).to eql '/main'
        expect(env['SERVER_NAME']).to eql 'serverhost'
        expect(env['SERVER_PORT']).to eql '80'
        expect(env['OTHER_METHOD']).to be nil
        Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
          expect(env[key]).to_not be(nil), "key: #{key.inspect} nil"
        end

        expect(env['rack.url_scheme']).to_not be nil
        expect(env['rack.version']).to_not be nil
        expect(env['jruby.rack.version']).to_not be nil

        expect(env['rack.run_once']).to be false
        expect(env['rack.multithread']).to be true

        expect(env['rack.whatever']).to be nil

        expect(env['HTTP_REFERER']).to eql 'http://www.example.com'
        expect(env['HTTP_X_FORWARDED_PROTO']).to_not be nil
        expect(env['HTTP_IF_NONE_MATCH']).to_not be nil
        expect(env['HTTP_IF_MODIFIED_SINCE']).to_not be nil
        expect(env['HTTP_X_SOME_REALLY_LONG_HEADER']).to_not be nil
        expect(env['HTTP_X_SOME_NON_EXISTENT_HEADER']).to be nil
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
      expect(hash).to be_a Hash
    end

    it "a new Hash is empty" do
      hash = new_hash
      expect(hash).to be_empty
    end

    it "allows filling a new Hash" do
      hash = new_hash
      hash['some'] = 'SOME'
      expect(hash['some']).to eql 'SOME'
    end

    it "allows iterating over a new Hash" do
      hash = new_hash
      hash['some'] = 'SOME'
      hash['more'] = ['MORE']
      expect(hash.keys.size).to be 2
      expect(hash.values.size).to be 2
      hash.each do |key, val|
        case key
        when 'some' then expect(val).to eql 'SOME'
        when 'more' then expect(val).to eql ['MORE']
        else fail("unexpected #{key.inspect} = #{val.inspect}")
        end
      end
    end

    it "sets all keys from the env Hash" do
      env = servlet.create_env(@servlet_env)
      hash = env.class.new
      env.keys.each { |k| hash[k] = env[k] if env.has_key?(k) }
      expect(hash.size).to eql env.size
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
      allow(@rack_context).to receive(:getServerInfo).and_return 'Trinidad'
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

      expect(env.keys).to include('REQUEST_METHOD')
      expect(env.keys).to include('SCRIPT_NAME')
      expect(env.keys).to include('PATH_INFO')
      expect(env.keys).to include('REQUEST_URI')
      expect(env.keys).to include('QUERY_STRING')
      expect(env.keys).to include('SERVER_NAME')
      expect(env.keys).to include('SERVER_PORT')
      expect(env.keys).to include('REMOTE_HOST')
      expect(env.keys).to include('REMOTE_ADDR')
      expect(env.keys).to include('REMOTE_USER')
      Rack::Handler::Servlet::DefaultEnv::BUILTINS.each do |key|
        expect(env.keys).to include(key)
      end

      expect(env.keys).to include('rack.version')
      expect(env.keys).to include('rack.input')
      expect(env.keys).to include('rack.errors')
      expect(env.keys).to include('rack.url_scheme')
      expect(env.keys).to include('rack.multithread')
      expect(env.keys).to include('rack.run_once')
      expect(env.keys).to include('java.servlet_context')
      expect(env.keys).to include('java.servlet_request')
      expect(env.keys).to include('java.servlet_response')
      Rack::Handler::Servlet::DefaultEnv::VARIABLES.each do |key|
        expect(env.keys).to include(key)
      end

      expect(env.keys).to include('HTTP_X_FORWARDED_PROTO')
      expect(env.keys).to include('HTTP_IF_NONE_MATCH')
      expect(env.keys).to include('HTTP_IF_MODIFIED_SINCE')
      expect(env.keys).to include('HTTP_X_SOME_REALLY_LONG_HEADER')
    end

  end

  context "servlet" do

    before do
      @servlet_context = org.springframework.mock.web.MockServletContext.new
      @servlet_request = org.springframework.mock.web.MockHttpServletRequest.new(@servlet_context)
      @servlet_response = org.springframework.mock.web.MockHttpServletResponse.new
      @servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
        @servlet_request, @servlet_response, @rack_context
      )
    end

    it "returns the servlet context when queried with java.servlet_context" do
      env = servlet.create_env @servlet_env

      expect(env['java.servlet_context']).to_not be nil
      if servlet_30?
        expect(env['java.servlet_context']).to be @servlet_context
      else
        expect(env['java.servlet_context']).to be @rack_context

        # HACK to emulate Servlet API 3.0 MockHttpServletRequest has getServletContext :
        env = Rack::Handler::Servlet::DefaultEnv.new(@servlet_request).to_hash

        expect(env['java.servlet_context']).to_not be nil
        expect(env['java.servlet_context']).to be @servlet_context
        begin
          expect(env['java.servlet_context']).to eq @servlet_context
        rescue NoMethodError
          expect((env['java.servlet_context'] == @servlet_context)).to eq true
        end
      end
    end

    it "returns the servlet request when queried with java.servlet_request" do
      env = servlet.create_env @servlet_env
      expect(env['java.servlet_request']).to be @servlet_request
    end

    it "returns the servlet response when queried with java.servlet_response" do
      env = servlet.create_env @servlet_env
      expect(env['java.servlet_response']).to be @servlet_response
    end

  end

  describe "call" do

    it "delegates to the inner application after constructing the env hash" do
      expect(servlet).to receive(:create_env).and_return({})
      servlet_env = double("servlet request")

      response = servlet.call(servlet_env)
      expect(response.to_java).to respond_to(:respond) # RackResponse

      expect(app._called?).to be true
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
      expect(servlet).to receive(:create_env).and_return({})

      servlet_env = double("servlet request")
      expect(servlet.call(servlet_env)).to be_a Rack::Handler::CustomResponse
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

      expect(rack_request.GET).to eq({ 'foo' => 'bar', 'bar' => 'huu', 'age' => '33' })
      expect(rack_request.POST).to eq({ "name" => ["Ferko Suska", "Jozko Hruska"], "age" => "30", "formula" => "a + b == 42%!" })
      expect(rack_request.params).to eq({
                                          "foo" => "bar", "bar" => "huu", "age" => "30",
                                          "name" => ["Ferko Suska", "Jozko Hruska"], "formula" => "a + b == 42%!"
                                        })

      expect(rack_request.query_string).to eq 'foo=bad&foo=bar&bar=huu&age=33'
      expect(rack_request.request_method).to eq 'POST'
      expect(rack_request.path_info).to eq '/path'
      expect(rack_request.script_name).to eq '/home' # context path
      expect(rack_request.content_length).to eq content.size.to_s
    end

    it "handles null values in parameter-map (Jetty)" do
      org.springframework.mock.web.MockHttpServletRequest.class_eval do
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
      servlet_request.parameters.put('age', [nil].to_java(:string)) # buggy container
      # POST params :
      servlet_request.addParameter('name[]', 'ferko')
      servlet_request.addParameter('name[]', 'jozko')

      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)

      expect(rack_request.GET).to eq({ 'foo' => 'huu', 'bar' => '', 'age' => '' })
      expect(rack_request.POST).to eq({ "name" => ["ferko", "jozko"] })
      expect(rack_request.params).to eq({
                                          "foo" => "huu", "bar" => "", "age" => "", "name" => ["ferko", "jozko"],
                                        })

      expect(rack_request.query_string).to eq 'foo=bar&foo=huu&bar=&age='
      expect(rack_request.request_method).to eq 'PUT'
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

      expect(rack_request.GET).to eq({ "foo" => "bar", "quux" => "b;la" })
      expect(rack_request.POST).to eq({})
      expect(rack_request.params).to eq({ "foo" => "bar", "quux" => "b;la" })

      expect(rack_request.query_string).to eq 'foo=bar&quux=b;la'
    end

    it "sets cookies from servlet requests" do
      cookies = []
      cookies << javax.servlet.http.Cookie.new('foo', 'bar')
      cookies << javax.servlet.http.Cookie.new('bar', '142')
      servlet_request.setCookies cookies.to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      expect(rack_request.cookies).to eq({ 'foo' => 'bar', 'bar' => '142' })
    end

    it "sets cookies from servlet requests (when empty)" do
      expect(servlet_request.getCookies).to be nil
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      expect(rack_request.cookies).to eq({})

      servlet_request.setCookies [].to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      expect(rack_request.cookies).to eq({})
    end

    it "sets a single cookie from servlet requests" do
      cookies = []
      cookies << javax.servlet.http.Cookie.new('foo', 'bar')
      cookies << javax.servlet.http.Cookie.new('foo', '142')
      servlet_request.setCookies cookies.to_java :'javax.servlet.http.Cookie'
      env = servlet.create_env(servlet_env)
      rack_request = Rack::Request.new(env)
      expect(rack_request.cookies).to eq({ 'foo' => 'bar' })
    end

    private

    def read_input_stream(input)
      while input.read != -1
      end
    end

  end

end