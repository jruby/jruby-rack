require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.DefaultRackApplication, "call" do

  before(:all) { require 'tempfile' }

  before :each do
    @rack_env = org.jruby.rack.RackEnvironment.impl do |name, *args|
      case name.to_s
      when 'getContext' then @rack_context
      when 'getInput' then StubInputStream.new("hello world!")
      when 'getContentLength' then 12
      end
    end
    @rack_response = org.jruby.rack.RackResponse.impl {}
  end

  it "invokes the call method on the ruby object and returns the rack response" do
    rack_app = double "application"
    expect(rack_app).to receive(:call).with(@rack_env).and_return(@rack_response)

    application = org.jruby.rack.DefaultRackApplication.new
    application.setApplication(rack_app)
    expect(application.call(@rack_env)).to eq @rack_response
  end

  let(:servlet_context) do
    servlet_context = double("servlet_context")
    allow(servlet_context).to receive(:getInitParameter) do |name|
      name && nil # return null
    end
    servlet_context
  end

  let(:servlet_request) do
    org.springframework.mock.web.MockHttpServletRequest.new(servlet_context)
  end

  let(:servlet_response) do
    org.springframework.mock.web.MockHttpServletResponse.new
  end

  let(:rack_config) do
    org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
  end

  let(:rack_context) do
    org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
  end

  context "with filter setup (using captures)" do

    let(:rack_env) do
      request_capture = org.jruby.rack.servlet.RequestCapture.new(servlet_request)
      response_capture = org.jruby.rack.servlet.ResponseCapture.new(servlet_response)
      org.jruby.rack.servlet.ServletRackEnvironment.new(request_capture, response_capture, rack_context)
    end

    it "should rewind body" do
      it_should_rewind_body
    end

  end

  context "with servlet setup (no captures)" do

    let(:rack_env) do
      org.jruby.rack.servlet.ServletRackEnvironment.new(servlet_request, servlet_response, rack_context)
    end

    it "should rewind body" do
      it_should_rewind_body
    end

  end

  def it_should_rewind_body
    content = ("Answer to the Ultimate Question of Life, the Universe, " <<
      "and Everything ...\n") * 42
    servlet_request.setContent content.to_java_bytes

    rack_app = double "application"
    expect(rack_app).to receive(:call) do |env|
      body = JRuby::Rack::Input.new(env)

      expect(body.read).to eq content
      expect(body.read).to eq ""
      body.rewind
      expect(body.read).to eq content

      org.jruby.rack.RackResponse.impl {}
    end

    application = org.jruby.rack.DefaultRackApplication.new
    application.setApplication(rack_app)
    application.call(rack_env)
  end

end

describe org.jruby.rack.DefaultRackApplicationFactory do

  before(:all) { require 'jruby/rack' }

  before :each do
    @app_factory = DefaultRackApplicationFactory.new
  end

  it "should receive a rackup script via the 'rackup' parameter" do
    expect(@rack_config).to receive(:getRackup).and_return 'run MyRackApp'
    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq 'run MyRackApp'
  end

  it "should look for a rackup script via the 'rackup.path' parameter" do
    expect(@rack_config).to receive(:getRackupPath).and_return '/WEB-INF/hello.ru'
    expect(@rack_context).to receive(:getResourceAsStream).with('/WEB-INF/hello.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq 'run MyRackApp'
  end

  it "should look for a config.ru rackup script below /WEB-INF" do
    expect(@rack_context).to receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ config.ru lib/ vendor/).map { |f| "/WEB-INF/#{f}" }))
    expect(@rack_context).to receive(:getRealPath).with('/WEB-INF/config.ru')
    expect(@rack_context).to receive(:getResourceAsStream).with('/WEB-INF/config.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq 'run MyRackApp'
  end

  it "should look for a config.ru script in subdirectories of /WEB-INF" do
    allow(@rack_context).to receive(:getResourcePaths).and_return java.util.HashSet.new
    expect(@rack_context).to receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ lib/ vendor/).map { |f| "/WEB-INF/#{f}" }))
    expect(@rack_context).to receive(:getResourcePaths).with('/WEB-INF/lib/').and_return(
      java.util.HashSet.new(["/WEB-INF/lib/config.ru"]))
    expect(@rack_context).to receive(:getResourceAsStream).with('/WEB-INF/lib/config.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq 'run MyRackApp'
  end

  it "should handle config.ru files with a coding: pragma" do
    expect(@rack_config).to receive(:getRackupPath).and_return '/WEB-INF/hello.ru'
    expect(@rack_context).to receive(:getResourceAsStream).with('/WEB-INF/hello.ru').
      and_return StubInputStream.new("# coding: us-ascii\nrun MyRackApp")
    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq "# coding: us-ascii\nrun MyRackApp"
  end

  it "initializes default request memory buffer size" do
    expect(@rack_config).to receive(:getInitialMemoryBufferSize).and_return 42
    expect(@rack_config).to receive(:getMaximumMemoryBufferSize).and_return 420
    @app_factory.init @rack_context

    a_stream = java.io.ByteArrayInputStream.new(''.to_java_bytes)
    input_stream = org.jruby.rack.servlet.RewindableInputStream.new(a_stream)
    expect(input_stream.getCurrentBufferSize).to eq 42
    expect(input_stream.getMaximumBufferSize).to eq 420
  end

  before do
    reset_booter
    JRuby::Rack.context = $servlet_context = nil
  end

  it "should init and create application object without a rackup script" do
    $servlet_context = @servlet_context
    # NOTE: a workaround to be able to mock it :
    klass = Class.new(DefaultRackApplicationFactory) do
      def createRackServletWrapper(runtime, rackup, filename)
        ;
      end
    end
    @app_factory = klass.new

    expect(@rack_context).to receive(:getRealPath).with('/config.ru').and_return nil
    # expect(@rack_context).to receive(:getContextPath).and_return '/'
    expect(@rack_config).to receive(:getRackup).and_return nil
    expect(@rack_config).to receive(:getRackupPath).and_return nil

    @app_factory.init @rack_context
    expect(@app_factory.rackup_script).to eq nil

    expect(@rack_context).to receive(:log) do |*args|
      expect(args.first.to_s).to eql 'WARN' if args.size > 1
      expect(args.last).to match(/no rackup script found/)
    end

    expect(@app_factory).to receive(:createRackServletWrapper) do |runtime, rackup|
      expect(runtime).to be(JRuby.runtime)
      expect(rackup).to eq ""
    end

    @app_factory.createApplicationObject(JRuby.runtime)
    expect(JRuby::Rack.booter).to be_a(JRuby::Rack::Booter)
  end

  private

  def reset_booter
    JRuby::Rack.send(:instance_variable_set, :@booter, self)
  end

  def mocked_runtime_application_factory(factory_class = nil)
    factory_class ||= org.jruby.rack.DefaultRackApplicationFactory
    klass = Class.new(factory_class) do
      def newRuntime()
        # use the current runtime instead of creating new
        require 'jruby'
        runtime = JRuby.runtime
        JRuby::Rack::Helpers.silence_warnings { initRuntime(runtime) }
        runtime
      end
    end
    klass.new
  end

  context "initialized" do

    before :each do
      allow(@rack_context).to receive(:getInitParameter).and_return nil
      allow(@rack_context).to receive(:getResourcePaths).and_return nil
      allow(@rack_context).to receive(:getRealPath) { |path| path }
      # allow(@rack_context).to receive(:log) do |*args|
      # puts args.inspect
      # end
    end

    let(:app_factory) do
      app_factory = mocked_runtime_application_factory
      app_factory.init(@rack_context); app_factory
    end

    describe "error application" do

      it "creates an error application (by default)" do
        expect(app_factory.getErrorApplication).to respond_to(:call)
      end

      it "creates a Rack error application" do
        error_application = app_factory.getErrorApplication
        expect(error_application).to be_a(org.jruby.rack.ErrorApplication)
        expect(error_application).to be_a(org.jruby.rack.DefaultRackApplication)
        # NOTE: these get created in a new Ruby runtime :
        rack_app = error_application.getApplication
        #    expect(rack_app).to be_a Rack::Handler::Servlet
        expect(rack_app.class.name).to eql 'Rack::Handler::Servlet'
        expect(rack_app.app).to be_a JRuby::Rack::ErrorApp::ShowStatus
        #    expect(app.class.name).to eql 'JRuby::Rack::ErrorApp::ShowStatus'
        error_app = rack_app.app.instance_variable_get('@app')
        expect(error_app).to be_a JRuby::Rack::ErrorApp
        #    expect(error_app.class.name).to eql 'JRuby::Rack::ErrorApp'
      end

      it "rackups a configured error application" do
        allow(@rack_config).to receive(:getProperty) do |name|
          if name == 'jruby.rack.error.app'
            "run Proc.new { 'error.app' }"
          else
            nil
          end
        end
        error_application = app_factory.getErrorApplication
        expect(error_application).to be_a(org.jruby.rack.ErrorApplication)
        expect(error_application).to be_a(org.jruby.rack.DefaultRackApplication)
        rack_app = error_application.getApplication
        expect(rack_app).to be_a Rack::Handler::Servlet
        #    expect(rack_app.class.name).to eql 'Rack::Handler::Servlet'
        expect(app = rack_app.get_app).to be_a Proc
        #    expect(app.class.name).to eql 'Proc'
        expect(app.call).to eql 'error.app'
      end

      it "creates a 'default' error application as a fallback" do
        allow(@rack_config).to receive(:getProperty) do |name|
          name == 'jruby.rack.error.app' ? "run MissingConstantApp" : nil
        end
        error_application = app_factory.getErrorApplication
        expect(error_application).to be_a(org.jruby.rack.ErrorApplication)

        rack_env = double("rack env")
        expect(rack_env).to receive(:getAttribute).with('jruby.rack.exception').
          at_least(:once).and_return java.lang.RuntimeException.new('42')
        response = error_application.call rack_env
        expect(response.getStatus).to eql 500
        expect(response.getHeaders).to be_empty
        expect(response.getBody).to_not be nil
      end

    end

    describe "newRuntime" do

      let(:app_factory) do
        @rack_config = org.jruby.rack.DefaultRackConfig.new
        allow(@rack_context).to receive(:getConfig).and_return @rack_config
        app_factory = org.jruby.rack.DefaultRackApplicationFactory.new
        app_factory.init(@rack_context); app_factory
      end

      it "creates a new Ruby runtime with the jruby-rack environment pre-loaded" do
        @runtime = app_factory.newRuntime
        should_not_eval_as_nil "defined?(::Rack)"
        should_not_eval_as_nil "defined?(::Rack::Handler::Servlet)"
        should_eval_as_nil "defined?(Rack::Handler::Bogus)"
      end

      it "does not require 'rack' (until booter is called)" do
        @runtime = app_factory.newRuntime
        should_eval_as_nil "defined?(::Rack::RELEASE)"
      end

      it "loads specified version of rack via bundler", :lib => :stub do
        gem_install_unless_installed 'rack', '1.3.6'
        set_config 'jruby.runtime.env', 'false'

        script = "# encoding: UTF-8\n" +
                 "# rack.version: bundler \n" +
                 "Proc.new { 'proc-rack-app' }"
        app_factory.setRackupScript script
        @runtime = app_factory.newRuntime

        file = Tempfile.new('Gemfile')
        file << "source 'https://rubygems.org'\n gem 'rack', '1.3.6'"
        file.flush
        @runtime.evalScriptlet "ENV['BUNDLE_GEMFILE'] = #{file.path.inspect}"
        @runtime.evalScriptlet "ENV['GEM_HOME'] = #{ENV['GEM_HOME'].inspect}"
        @runtime.evalScriptlet "ENV['GEM_PATH'] = #{ENV['GEM_PATH'].inspect}"

        app_factory.checkAndSetRackVersion(@runtime)
        @runtime.evalScriptlet "require 'rack'"

        should_not_eval_as_nil "defined?(Bundler)"
        should_eval_as_eql_to "Rack.release if defined? Rack.release", '1.3'
        should_eval_as_eql_to "Gem.loaded_specs['rack'].version.to_s", '1.3.6'
      end

      it "initializes the $servlet_context global variable" do
        @runtime = app_factory.new_runtime
        should_not_eval_as_nil "defined?($servlet_context)"
      end

      it "clears environment variables if the configuration ignores the environment" do
        expect(ENV['HOME']).to_not eql ""
        set_config 'jruby.runtime.env', ''

        @runtime = app_factory.newRuntime
        should_eval_as_nil "ENV['HOME']"
        should_eval_as_nil "ENV['RUBYOPT']"
      end

      it "sets ENV['PATH'] to an empty string if the configuration ignores the environment" do
        expect(ENV['PATH']).to_not be_empty
        set_config 'jruby.runtime.env', 'false'

        @runtime = app_factory.newRuntime
        should_eval_as_eql_to "ENV['PATH']", ''
      end

      it "allows to keep RUBYOPT with a clear environment" do
        set_config 'jruby.runtime.env', 'false'
        set_config 'jruby.runtime.env.rubyopt', 'true'

        app_factory = app_factory_with_RUBYOPT '-U'
        @runtime = app_factory.newRuntime
        should_eval_as_nil "ENV['HOME']"
        should_eval_as_eql_to "ENV['RUBYOPT']", '-U'
      end

      it "does a complete ENV clean including RUBYOPT" do
        set_config 'jruby.runtime.env', 'false'
        # set_config 'jruby.runtime.env.rubyopt', 'false'

        app_factory = app_factory_with_RUBYOPT '-ryaml'
        @runtime = app_factory.newRuntime

        should_eval_as_nil "ENV['HOME']"
        should_eval_as_nil "ENV['RUBYOPT']"
        should_eval_as_eql_to "require 'yaml'", true # -ryaml not processed
      end

      it "handles jruby.runtime.arguments == '-X+O -Ke' and start with object space enabled and KCode EUC" do
        set_config 'jruby.runtime.arguments', '-X+O -Ke'
        # allow(@rack_config).to receive(:getRuntimeArguments).and_return ['-X+O', '-Ke'].to_java(:String)
        @runtime = app_factory.new_runtime
        expect(@runtime.object_space_enabled).to be_truthy
        expect(@runtime.kcode).to eq Java::OrgJrubyUtil::KCode::EUC
      end

      it "does not propagate ENV changes to JVM (and indirectly to other JRuby VM instances)" do
        runtime = app_factory.new_runtime

        expect(java.lang.System.getenv['VAR1']).to be_nil
        # Nil returned from Ruby VM don't have the rspec decorations'
        expect(runtime.evalScriptlet("ENV['VAR1']")).to be_nil
        result = runtime.evalScriptlet("ENV['VAR1'] = 'VALUE1';")

        # String returned from Ruby VM don't have the rspec decorations'
        expect(String.new(result)).to eq 'VALUE1'
        expect(java.lang.System.getenv['VAR1']).to be_nil
      end

      private

      def app_factory_with_RUBYOPT(rubyopt)
        app_factory =
          Class.new(org.jruby.rack.DefaultRackApplicationFactory) do

            def initialize(rubyopt)
              ; super(); @rubyopt = rubyopt;
            end

            def initRuntimeConfig(config)
              env = java.util.HashMap.new config.getEnvironment
              env.put 'RUBYOPT', @rubyopt
              config.setEnvironment env
              super
            end

          end.new(rubyopt)
        @rack_config = org.jruby.rack.DefaultRackConfig.new
        allow(@rack_context).to receive(:getConfig).and_return @rack_config
        app_factory.init(@rack_context)
        app_factory
      end

      def set_runtime_environment(value)
        set_config 'jruby.runtime.env', value.to_s
      end

      def set_config(name, value)
        # NOTE: we're using DefaultRackConfig which checks java.lang.System
        @_prev_properties ||= {}
        @_prev_properties[name] = java.lang.System.getProperty(name)
        java.lang.System.setProperty(name, value)
      end

      def reset_config
        (@_prev_properties || {}).each do |key, val|
          if val.nil?
            java.lang.System.clearProperty(key)
          else
            java.lang.System.setProperty(key, val)
          end
        end
      end

      after { reset_config }

    end

  end

  describe "newApplication" do
    before :each do
      allow(@rack_context).to receive(:getRealPath).and_return Dir::tmpdir
    end

    it "creates a Ruby object from the script snippet given" do
      expect(@rack_config).to receive(:getRackup).and_return("require 'rack/lobster'; Rack::Lobster.new")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      app_object = app_factory.newApplication
      expect(app_object.respond_to?(:call)).to eq true
    end

    it "raises an exception if creation failed" do
      expect(@rack_config).to receive(:getRackup).and_return("raise 'something went wrong'")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      app_object = app_factory.newApplication
      begin
        app_object.init
        fail "expected to raise"
      rescue => e
        expect(e.message).to eql 'something went wrong'
      end
    end
  end

  describe "getApplication" do
    it "creates an application and initializes it" do
      expect(@rack_config).to receive(:getRackup).and_return("raise 'init was called'")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      begin
        app_factory.getApplication
        fail "expected to raise"
      rescue => e
        expect(e.message).to eql 'init was called'
      end
      # expect { app_factory.getApplication }.to raise_error
    end
  end

  describe "finishedWithApplication" do
    it "should call destroy on the application object" do
      rack_app = double "application"
      expect(rack_app).to receive(:destroy)
      @app_factory.finishedWithApplication rack_app
    end
  end

  describe "destroy" do
    it "should call destroy on the error application" do
      rack_app = double "error app"
      expect(rack_app).to receive(:destroy)
      @app_factory.setErrorApplication rack_app
      @app_factory.destroy
    end
  end
end

describe org.jruby.rack.rails.RailsRackApplicationFactory do

  java_import org.jruby.rack.rails.RailsRackApplicationFactory

  before :each do
    @app_factory = RailsRackApplicationFactory.new
    JRuby::Rack.context = @servlet_context
  end

  after :each do
    JRuby::Rack.context = nil
  end

  it "should init and create application object" do
    # NOTE: a workaround to be able to mock it :
    klass = Class.new(RailsRackApplicationFactory) do
      def createRackServletWrapper(runtime, rackup, filename)
        ;
      end
    end
    @app_factory = klass.new

    expect(@rack_context).to receive(:getRealPath).with('/config.ru').and_return nil
    # expect(@rack_context).to receive(:getContextPath).and_return '/'
    expect(@rack_config).to receive(:getRackup).and_return nil
    expect(@rack_config).to receive(:getRackupPath).and_return nil

    @app_factory.init @rack_context

    expect(@app_factory).to receive(:createRackServletWrapper) do |runtime, rackup|
      expect(runtime).to be(JRuby.runtime)
      expect(rackup).to eq "run JRuby::Rack::RailsBooter.to_app"
    end
    expect(JRuby::Rack::RailsBooter).to receive(:load_environment)

    @app_factory.createApplicationObject(JRuby.runtime)
    expect(JRuby::Rack.booter).to be_a(JRuby::Rack::RailsBooter)
  end

end

describe org.jruby.rack.PoolingRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @pooling_factory = org.jruby.rack.PoolingRackApplicationFactory.new @factory
    @pooling_factory.context = @rack_context
  end

  it "should initialize the delegate factory when initialized" do
    expect(@factory).to receive(:init).with(@rack_context)
    @pooling_factory.init(@rack_context)
  end

  it "should start out empty" do
    expect(@pooling_factory.getApplicationPool).to be_empty
  end

  it "should create a new application when empty" do
    app = double "app"
    expect(@factory).to receive(:getApplication).and_return app
    expect(@pooling_factory.getApplication).to eq app
  end

  it "should not add newly created application to pool" do
    app = double "app"
    expect(@factory).to receive(:getApplication).and_return app
    expect(@pooling_factory.getApplication).to eq app
    expect(@pooling_factory.getApplicationPool.to_a).to eq []
  end

  it "accepts an existing application and puts it back in the pool" do
    app = double "app"
    expect(@pooling_factory.getApplicationPool.to_a).to eq []
    @pooling_factory.finishedWithApplication app
    expect(@pooling_factory.getApplicationPool.to_a).to eq [app]
    expect(@pooling_factory.getApplication).to eq app
  end

  it "calls destroy on all cached applications when destroyed" do
    app1, app2 = double("app1"), double("app2")
    @pooling_factory.finishedWithApplication app1
    @pooling_factory.finishedWithApplication app2
    expect(@factory).to receive(:finishedWithApplication).with(app1) # expect(app1).to receive(:destroy)
    expect(@factory).to receive(:finishedWithApplication).with(app2) # expect(app2).to receive(:destroy)
    expect(@factory).to receive(:destroy)

    @pooling_factory.destroy
    expect(@pooling_factory.getApplicationPool.to_a).to eq [] # and empty application pool
  end

  it "creates applications during initialization according to the jruby.min.runtimes context parameter" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      expect(app).to receive(:init)
      app
    end
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 1
    @pooling_factory.init(@rack_context)
    expect(@pooling_factory.getApplicationPool.size).to eq 1
  end

  it "does not allow new applications beyond the maximum specified by the jruby.max.runtimes context parameter" do
    allow(@factory).to receive(:init)
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 1

    @pooling_factory.init(@rack_context)
    @pooling_factory.finishedWithApplication double("app1")
    @pooling_factory.finishedWithApplication double("app2")
    expect(@pooling_factory.getApplicationPool.size).to eq 1
  end

  it "does not add an application back into the pool if it already exists" do
    allow(@factory).to receive(:init)
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 4
    @pooling_factory.init(@rack_context)
    rack_application_1 = double("app1")
    @pooling_factory.finishedWithApplication rack_application_1
    @pooling_factory.finishedWithApplication rack_application_1

    expect(@pooling_factory.getApplicationPool.size).to eq 1
  end

  it "forces the maximum size to be greater or equal to the initial size" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      expect(app).to receive(:init)
      app
    end
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 2
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 1

    @pooling_factory.init(@rack_context)
    expect(@pooling_factory.getApplicationPool.size).to eq 2
    @pooling_factory.finishedWithApplication double("app")
    expect(@pooling_factory.getApplicationPool.size).to eq 2
  end

  it "retrieves the error application from the delegate factory" do
    app = double("app")
    expect(@factory).to receive(:getErrorApplication).and_return app
    expect(@pooling_factory.getErrorApplication).to eq app
  end

  it "waits till initial runtimes get initialized (with wait set to true)" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) do
        sleep(0.10)
      end
      app
    end
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return true
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 4
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    expect(@pooling_factory.getApplicationPool.size).to be >= 4
  end

  it "throws an exception from getApplication when an app failed to initialize " +
     "(even when only a single application initialization fails)" do
    allow(@factory).to receive(:init)
    app_count = java.util.concurrent.atomic.AtomicInteger.new(0)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) do
        if app_count.addAndGet(1) == 2
          raise org.jruby.rack.RackInitializationException.new('failed app init')
        end
        sleep(0.05)
      end
      app
    end
    num_runtimes = 3
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    expect(@rack_config).to receive(:getInitialRuntimes).and_return num_runtimes
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return num_runtimes

    begin
      @pooling_factory.init(@rack_context)
    rescue org.jruby.rack.RackInitializationException
      # ignore - sometimes initialization happens fast enough that the init error is thrown already
    end
    sleep(0.20)

    failed = 0
    num_runtimes.times do
      begin
        @pooling_factory.getApplication
      rescue org.jruby.rack.RackInitializationException
        failed += 1
      end
    end
    if failed != num_runtimes
      fail "@pooling_factory.getApplication expected to fail #{num_runtimes} times, but failed #{failed} time(s)"
    end
  end

  it "wait until pool is filled when invoking getApplication (with wait set to false)" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) { sleep(0.2) }
      app
    end
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 3
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 4

    @pooling_factory.init(@rack_context)
    millis = java.lang.System.currentTimeMillis
    expect(@pooling_factory.getApplication).not_to be nil
    millis = java.lang.System.currentTimeMillis - millis
    expect(millis).to be >= 150 # getApplication waited ~ 0.2 secs
  end

  it "waits acquire timeout till an application is available from the pool (than raises)" do
    allow(@factory).to receive(:init)
    expect(@factory).to receive(:newApplication).twice do
      app = double "app"
      expect(app).to receive(:init) { sleep(0.2) }
      app
    end
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 2
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 2

    @pooling_factory.init(@rack_context)
    @pooling_factory.acquire_timeout = 1.to_java # second
    millis = java.lang.System.currentTimeMillis
    expect(@pooling_factory.getApplication).not_to be nil
    millis = java.lang.System.currentTimeMillis - millis
    expect(millis).to be >= 150 # getApplication waited ~ 0.2 secs

    app2 = @pooling_factory.getApplication # now the pool is empty

    @pooling_factory.acquire_timeout = 0.1.to_java # second
    millis = java.lang.System.currentTimeMillis
    expect { @pooling_factory.getApplication }.to raise_error(org.jruby.rack.AcquireTimeoutException)
    millis = java.lang.System.currentTimeMillis - millis
    expect(millis).to be >= 90 # waited about ~ 0.1 secs

    @pooling_factory.finishedWithApplication(app2) # gets back to the pool
    expect(@pooling_factory.getApplication).to eq app2
  end

  it "gets and initializes new applications until maximum allows to create more" do
    allow(@factory).to receive(:init)
    expect(@factory).to receive(:newApplication).twice do
      app = double "app (new)"
      expect(app).to receive(:init) { sleep(0.1) }
      app
    end
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    allow(@rack_config).to receive(:getInitialRuntimes).and_return 2
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return 4

    @pooling_factory.init(@rack_context)
    @pooling_factory.acquire_timeout = 0.10.to_java # second

    2.times { expect(@pooling_factory.getApplication).not_to be nil }

    expect(@factory).to receive(:getApplication).twice do
      app = double "app (get)"; sleep(0.15); app
    end

    millis = java.lang.System.currentTimeMillis
    2.times { expect(@pooling_factory.getApplication).not_to be nil }
    millis = java.lang.System.currentTimeMillis - millis
    expect(millis).to be >= 300 # waited about 2 x 0.15 secs

    millis = java.lang.System.currentTimeMillis
    expect {
      @pooling_factory.getApplication
    }.to raise_error(org.jruby.rack.AcquireTimeoutException)
    millis = java.lang.System.currentTimeMillis - millis
    expect(millis).to be >= 90 # waited about ~ 0.10 secs
  end

  it "initializes initial runtimes in paralel (with wait set to false)" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) do
        sleep(0.15)
      end
      app
    end
    allow(@rack_config).to receive(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    allow(@rack_config).to receive(:getInitialRuntimes).and_return 6
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    sleep(0.10)
    expect(@pooling_factory.getApplicationPool.size).to be < 6
    sleep(0.9)
    expect(@pooling_factory.getApplicationPool.size).to be >= 6

    expect(@pooling_factory.getManagedApplications).to_not be_empty
    expect(@pooling_factory.getManagedApplications.size).to eql 6
  end

  it "throws from init when application initialization in thread failed" do
    allow(@factory).to receive(:init)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) do
        sleep(0.05); raise "app.init raising"
      end
      app
    end
    allow(@rack_config).to receive(:getInitialRuntimes).and_return 2
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return 2

    raise_error_logged = 0
    allow(@rack_context).to receive(:log) do |level, msg, e|
      if level.to_s == 'ERROR'
        expect(msg).to eql 'unable to initialize application'
        expect(e).to be_a org.jruby.exceptions.RaiseException
        raise_error_logged += 1
      else
        true
      end
    end

    expect { @pooling_factory.init(@rack_context) }.to raise_error org.jruby.rack.RackInitializationException
    expect(raise_error_logged).to eql 1 # logs same init exception once

    # NOTE: seems it's not such a good idea to return empty on init error
    #     expect(@pooling_factory.getManagedApplications).to be_empty
  end

end

describe org.jruby.rack.SerialPoolingRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @pooling_factory = org.jruby.rack.SerialPoolingRackApplicationFactory.new @factory
    @pooling_factory.context = @rack_context
  end

  it "initializes initial runtimes in serial order" do
    expect(@factory).to receive(:init).with(@rack_context)
    allow(@factory).to receive(:newApplication) do
      app = double "app"
      allow(app).to receive(:init) do
        sleep(0.05)
      end
      app
    end
    expect(@rack_config).to receive(:getInitialRuntimes).and_return 6
    expect(@rack_config).to receive(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    expect(@pooling_factory.getApplicationPool.size).to eq 6
  end

end

describe org.jruby.rack.SharedRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @shared_factory = org.jruby.rack.SharedRackApplicationFactory.new @factory
  end

  it "initializes the delegate factory and creates the (shared) application when initialized" do
    expect(@factory).to receive(:init).with(@rack_context)
    expect(@factory).to receive(:getApplication).and_return app = double("application")
    @shared_factory.init(@rack_context)

    expect(@shared_factory.getManagedApplications).to_not be_empty
    expect(@shared_factory.getManagedApplications.size).to eql 1
    expect(@shared_factory.getManagedApplications.to_a[0]).to be app
  end

  it "throws an exception if the shared application cannot be initialized " do
    expect(@factory).to receive(:init).with(@rack_context)
    expect(@factory).to receive(:getApplication).and_raise java.lang.ArithmeticException.new('42')

    expect(@rack_context).to receive(:log) do |level, msg, e|
      if level == 'ERROR'
        expect(e).to be_a java.lang.ArithmeticException
      else
        true
      end
    end

    begin
      @shared_factory.init(@rack_context)
    rescue org.jruby.rack.RackInitializationException => e
      expect(e.message).to eql 'java.lang.ArithmeticException: 42'
    else
      fail "expected to rescue RackInitializationException"
    end

    expect(@shared_factory.getManagedApplications).to be nil
  end

  it "throws initialization exception on each getApplication call if init failed" do
    expect(@factory).to receive(:init).with(@rack_context)
    expect(@factory).to receive(:getApplication).and_raise java.lang.RuntimeException.new('42')
    expect(@factory).not_to receive(:getErrorApplication) # dispacther invokes this ...

    begin
      @shared_factory.init(@rack_context)
    rescue java.lang.RuntimeException => e
      # NOOP
    end
    expect { @shared_factory.getApplication }.to raise_error(org.jruby.rack.RackInitializationException)
  end

  it "returns the same application for any newApplication or getApplication call" do
    expect(@factory).to receive(:init).with(@rack_context)
    expect(@factory).to receive(:getApplication).and_return app = double("application")
    @shared_factory.init(@rack_context)
    1.upto(5) do
      expect(@shared_factory.newApplication).to eq app
      expect(@shared_factory.getApplication).to eq app
      @shared_factory.finishedWithApplication app
    end
  end

  it "finished with application using delegate factory when destroyed" do
    expect(@factory).to receive(:init).with(@rack_context)
    expect(@factory).to receive(:getApplication).and_return app = double("application")
    expect(@factory).to receive(:destroy)
    expect(@factory).to receive(:finishedWithApplication).with(app)
    @shared_factory.init(@rack_context)
    @shared_factory.destroy
  end

  it "retrieves the error application from the delegate factory" do
    expect(@factory).to receive(:getErrorApplication).and_return app = double("error app")
    expect(@shared_factory.getErrorApplication).to eq app
  end

end