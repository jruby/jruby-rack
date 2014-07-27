#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')
require 'tempfile'

describe org.jruby.rack.DefaultRackApplication, "call" do

  before :each do
    @rack_env = double("rack request env")
    @rack_env.stub(:getContext).and_return @rack_context
    @rack_env.stub(:getInput).and_return(StubInputStream.new("hello world!"))
    @rack_env.stub(:getContentLength).and_return(12)
    @rack_response = org.jruby.rack.RackResponse.impl {}
  end

  it "invokes the call method on the ruby object and returns the rack response" do
    ruby_object = double "application"
    ruby_object.should_receive(:call).with(@rack_env).and_return do |servlet_env|
      servlet_env.to_io.read.should == "hello world!"
      @rack_response
    end

    application = org.jruby.rack.DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(@rack_env).should == @rack_response
  end

  let(:servlet_context) do
    servlet_context = double("servlet_context")
    servlet_context.stub(:getInitParameter).and_return do |name|
      name && nil # return null
    end
    servlet_context
  end

  let(:servlet_request) do
    org.jruby.rack.mock.MockHttpServletRequest.new(servlet_context)
  end

  let(:servlet_response) do
    org.jruby.rack.mock.MockHttpServletResponse.new
  end

  let(:rack_config) do
    org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
  end

  let(:rack_context) do
    org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
  end

  context "with filter setup (using captures)" do

    let(:rack_env) do
      request_capture = org.jruby.rack.servlet.RequestCapture.new(servlet_request, rack_config)
      response_capture = org.jruby.rack.servlet.ResponseCapture.new(servlet_response)
      rack_env = org.jruby.rack.servlet.ServletRackEnvironment.new(request_capture, response_capture, rack_context)
      set_rack_input rack_env
      rack_env
    end

    it "should rewind body" do
      it_should_rewind_body
    end

  end

  context "with servlet setup (no captures)" do

    let(:rack_env) do
      rack_env = org.jruby.rack.servlet.ServletRackEnvironment.new(servlet_request, servlet_response, rack_context)
      set_rack_input rack_env
      rack_env
    end

    it "should rewind body" do
      it_should_rewind_body
    end

  end

  def it_should_rewind_body
    content = ''
    42.times { content << "Answer to the Ultimate Question of Life, the Universe, and Everything ...\n" }
    servlet_request.setContent content.to_java_bytes

    rack_app = double "application"
    rack_app.should_receive(:call) do |env|
      body = env.to_io

      body.read.should == content
      body.read.should == ""
      body.rewind
      body.read.should == content

      org.jruby.rack.RackResponse.impl {}
    end

#    rack_app = Object.new
#    def rack_app.call(env)
#      body = env.to_io
#
#      body.read.should == @content
#      body.read.should == ""
#      body.rewind
#      body.read.should == @content
#
#      org.jruby.rack.RackResponse.impl {}
#    end
#    rack_app.instance_variable_set :@content, content

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
    @rack_config.should_receive(:getRackup).and_return 'run MyRackApp'
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a rackup script via the 'rackup.path' parameter" do
    @rack_config.should_receive(:getRackupPath).and_return '/WEB-INF/hello.ru'
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a config.ru rackup script below /WEB-INF" do
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ config.ru lib/ vendor/).map{|f| "/WEB-INF/#{f}"}))
    @rack_context.should_receive(:getRealPath).with('/WEB-INF/config.ru')
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/config.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a config.ru script in subdirectories of /WEB-INF" do
    @rack_context.stub(:getResourcePaths).and_return java.util.HashSet.new
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ lib/ vendor/).map{|f| "/WEB-INF/#{f}"}))
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/lib/').and_return(
      java.util.HashSet.new(["/WEB-INF/lib/config.ru"]))
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/lib/config.ru').
      and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should handle config.ru files with a coding: pragma" do
    @rack_config.should_receive(:getRackupPath).and_return '/WEB-INF/hello.ru'
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').
      and_return StubInputStream.new("# coding: us-ascii\nrun MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == "# coding: us-ascii\nrun MyRackApp"
  end

  it "initializes default request memory buffer size" do
    @rack_config.should_receive(:getInitialMemoryBufferSize).and_return 42
    @rack_config.should_receive(:getMaximumMemoryBufferSize).and_return 420
    @app_factory.init @rack_context

    a_stream = java.io.ByteArrayInputStream.new(''.to_java_bytes)
    input_stream = org.jruby.rack.servlet.RewindableInputStream.new(a_stream)
    input_stream.getCurrentBufferSize.should == 42
    input_stream.getMaximumBufferSize.should == 420
  end

  before do
    reset_booter
    JRuby::Rack.context = $servlet_context = nil
  end

  it "should init and create application object without a rackup script" do
    $servlet_context = @servlet_context
    # NOTE: a workaround to be able to mock it :
    klass = Class.new(DefaultRackApplicationFactory) do
      def createRackServletWrapper(runtime, rackup); end
    end
    @app_factory = klass.new

    @rack_context.should_receive(:getRealPath).with('/config.ru').and_return nil
    #@rack_context.should_receive(:getContextPath).and_return '/'
    @rack_config.should_receive(:getRackup).and_return nil
    @rack_config.should_receive(:getRackupPath).and_return nil

    @app_factory.init @rack_context
    @app_factory.rackup_script.should == nil

    @rack_context.should_receive(:log).with do |*args|
      args.first.should == 'WARN' if args.size > 1
      args.last.should =~ /no rackup script found/
    end

    @app_factory.should_receive(:createRackServletWrapper) do |runtime, rackup|
      runtime.should be JRuby.runtime
      rackup.should == ""
    end

    @app_factory.createApplicationObject(JRuby.runtime)
    JRuby::Rack.booter.should be_a(JRuby::Rack::Booter)
  end

  private

  def reset_booter
    JRuby::Rack.send(:instance_variable_set, :@booter, self)
  end

  def mocked_runtime_application_factory(factory_class = nil)
    factory_class ||= org.jruby.rack.DefaultRackApplicationFactory
    klass = Class.new(factory_class) do
      def newRuntime() # use the current runtime instead of creating new
        require 'jruby'
        runtime = JRuby.runtime
        initRuntime(runtime)
        runtime
      end
    end
    klass.new
  end

  context "initialized" do

    before :each do
      @rack_context.stub(:getInitParameter).and_return nil
      @rack_context.stub(:getResourcePaths).and_return nil
      @rack_context.stub(:getRealPath) { |path| path }
      #@rack_context.stub(:log).with do |*args|
        #puts args.inspect
      #end
    end

    let(:app_factory) do
      app_factory = mocked_runtime_application_factory
      app_factory.init(@rack_context); app_factory
    end

    describe "error application" do

      it "creates an error application (by default)" do
        app_factory.getErrorApplication.should respond_to(:call)
      end

      it "creates a Rack error application" do
        error_application = app_factory.getErrorApplication
        expect( error_application ).to be_a(org.jruby.rack.ErrorApplication)
        expect( error_application ).to be_a(org.jruby.rack.DefaultRackApplication)
        # NOTE: these get created in a new Ruby runtime :
        rack_app = error_application.getApplication
        #expect( rack_app ).to be_a Rack::Handler::Servlet
        expect( rack_app.class.name ).to eql 'Rack::Handler::Servlet'
        app = rack_app.instance_variable_get('@app')
        expect( app ).to be_a Rack::ShowStatus
        #expect( app.class.name ).to eql 'Rack::ShowStatus'
        error_app = app.instance_variable_get('@app')
        expect( error_app ).to be_a JRuby::Rack::ErrorApp
        #expect( error_app.class.name ).to eql 'JRuby::Rack::ErrorApp'
      end

      it "rackups a configured error application" do
        @rack_config.stub(:getProperty) do |name|
          if name == 'jruby.rack.error.app'
            "run Proc.new { 'error.app' }"
          else
            nil
          end
        end
        error_application = app_factory.getErrorApplication
        expect( error_application ).to be_a(org.jruby.rack.ErrorApplication)
        expect( error_application ).to be_a(org.jruby.rack.DefaultRackApplication)
        rack_app = error_application.getApplication
        expect( rack_app ).to be_a Rack::Handler::Servlet
        #expect( rack_app.class.name ).to eql 'Rack::Handler::Servlet'
        app = rack_app.instance_variable_get('@app')
        expect( app ).to be_a Proc
        #expect( app.class.name ).to eql 'Proc'
        expect( app.call ).to eql 'error.app'
      end

      it "creates a 'default' error application as a fallback" do
        @rack_config.stub(:getProperty) do |name|
          name == 'jruby.rack.error.app' ? "run MissingConstantApp" : nil
        end
        error_application = app_factory.getErrorApplication
        expect( error_application ).to be_a(org.jruby.rack.ErrorApplication)

        rack_env = double("rack env")
        rack_env.should_receive(:getAttribute).with('jruby.rack.exception').
          at_least(:once).and_return java.lang.RuntimeException.new('42')
        response = error_application.call rack_env
        expect( response.getStatus ).to eql 500
        expect( response.getHeaders ).to be_empty
        expect( response.getBody ).to_not be nil
      end

    end

    describe "newRuntime" do

      let(:app_factory) do
        @rack_config = org.jruby.rack.DefaultRackConfig.new
        @rack_context.stub(:getConfig).and_return @rack_config
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
        should_eval_as_nil "defined?(::Rack::VERSION)"
      end

      it "loads specified version of rack", :lib => :stub do
        gem_install_rack_unless_installed '1.3.10'
        set_config 'jruby.runtime.env', 'false'

        script = "" +
          "# rack.version: ~>1.3.6\n" +
          "Proc.new { 'proc-rack-app' }"
        app_factory.setRackupScript script
        @runtime = app_factory.newRuntime
        @runtime.evalScriptlet "ENV['GEM_HOME'] = #{ENV['GEM_HOME'].inspect}"
        @runtime.evalScriptlet "ENV['GEM_PATH'] = #{ENV['GEM_PATH'].inspect}"

        app_factory.checkAndSetRackVersion(@runtime)
        @runtime.evalScriptlet "require 'rack'"

        should_eval_as_eql_to "Rack.release if defined? Rack.release", '1.3'
        should_eval_as_eql_to "Gem.loaded_specs['rack'].version.to_s", '1.3.10'
      end

      it "loads bundler with rack", :lib => :stub do
        gem_install_rack_unless_installed '1.3.6'
        set_config 'jruby.runtime.env', 'false'

        script = "# encoding: UTF-8\n" +
          "# rack.version: bundler \n" +
          "Proc.new { 'proc-rack-app' }"
        app_factory.setRackupScript script
        @runtime = app_factory.newRuntime

        file = Tempfile.new('Gemfile')
        file << "source 'http://rubygems.org'\n gem 'rack', '1.3.6'"
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

      def gem_install_rack_unless_installed(version)
        begin
          if Gem::Specification.respond_to? :find_by_name
            Gem::Specification.find_by_name 'rack', version
          else
            raise Gem::LoadError unless Gem.available? 'rack', version
          end
        rescue Gem::LoadError
          require 'rubygems/dependency_installer'
          installer = Gem::DependencyInstaller.new
          installer.install 'rack', version
        end
      end

      # should not matter on 1.7.x due https://github.com/jruby/jruby/pull/123
      if JRUBY_VERSION < '1.7.0'
        it "does not load any features (until load path is adjusted)" do
          set_runtime_environment("false")
          # due to incorrectly detected jruby.home some container e.g. WebSphere 8
          # fail if things such as 'fileutils' get required during runtime init !

          # TODO: WTF? JRuby magic - $LOADED_FEATURES seems to get "inherited" if
          # Ruby.newInstance(config) is called with the factory's defaultConfig,
          # but only if it's executed with bundler e.g. `bundle exec rake spec`
          #@runtime = app_factory.new_runtime
          @runtime = org.jruby.Ruby.newInstance
          app_factory.send :initRuntime, @runtime

          #@runtime.evalScriptlet 'puts "initRuntime $LOADED_FEATURES: #{$LOADED_FEATURES.inspect}"'
          # NOTE: the above scriptlet behaves slightly different on Travis-CI
          # depending on whether jruby + JRUBY_OPTS="--1.9" is used and or using
          # jruby-19mode with the later the LOADED_FEATURES do get expanded e.g. :
          #
          #   "/home/travis/builds/kares/jruby-rack/target/classes/rack/handler/servlet.rb",
          #   "/home/travis/builds/kares/jruby-rack/target/classes/jruby/rack.rb",
          #   "/home/travis/builds/kares/jruby-rack/target/classes/jruby/rack/environment.rb",
          #   "java.rb",
          #   "/home/travis/.rvm/rubies/jruby-1.6.8-d19/lib/ruby/site_ruby/shared/builtin/javasupport.rb",
          #   "/home/travis/.rvm/rubies/jruby-1.6.8-d19/lib/ruby/site_ruby/shared/builtin/javasupport/java.rb",
          #   ...
          #
          # compared to jruby --1.9 :
          #
          #   "enumerator.jar",
          #   "rack/handler/servlet.rb",
          #   "jruby/rack.rb",
          #   "jruby/rack/environment.rb",
          #   "java.rb",
          #   "builtin/javasupport.rb",
          #   "builtin/javasupport/java.rb",
          #   ...

          reject_files =
            "p =~ /.jar$/ || " +
            "p =~ /^builtin/ || " +
            "p =~ /java.rb$/ || p =~ /jruby.rb$/ || " +
            "p =~ /jruby\\/java.*.rb/ || " +
            "p =~ /jruby\\/rack.*.rb/ || " +
            "p =~ /^rack\\/handler\\/servlet/"
          # NOTE: fails with JRuby 1.7 as it has all kind of things loaded e.g. :
          # thread.rb, rbconfig.rb, java.rb, lib/ruby/shared/rubygems.rb etc
          should_eval_as_eql_to "$LOADED_FEATURES.reject { |p| #{reject_files} }", []
        end
      end

      it "initializes the $servlet_context global variable" do
        @runtime = app_factory.new_runtime
        should_not_eval_as_nil "defined?($servlet_context)"
      end

      it "clears environment variables if the configuration ignores the environment" do
        expect( ENV['HOME'] ).to_not eql ""
        set_config 'jruby.runtime.env', ''

        @runtime = app_factory.newRuntime
        should_eval_as_nil "ENV['HOME']"
        should_eval_as_nil "ENV['RUBYOPT']"
      end

      it "sets ENV['PATH'] to an empty string if the configuration ignores the environment" do
        expect( ENV['PATH'] ).to_not be_empty
        set_config 'jruby.runtime.env', 'false'

        @runtime = app_factory.newRuntime
        should_eval_as_eql_to "ENV['PATH']", ''
      end

      it "allows to keep RUBYOPT with a clear environment" do
        set_config 'jruby.runtime.env', 'false'
        set_config 'jruby.runtime.env.rubyopt', 'true'

        app_factory = app_factory_with_RUBYOPT '-rubygems'
        @runtime = app_factory.newRuntime
        should_eval_as_nil "ENV['HOME']"
        should_eval_as_eql_to "ENV['RUBYOPT']", '-rubygems'
      end

      it "keeps RUBYOPT by default with empty ENV (backwards compat)" do
        set_config 'jruby.rack.ignore.env', 'true'

        app_factory = app_factory_with_RUBYOPT '-ryaml'
        @runtime = app_factory.newRuntime
        should_eval_as_nil "ENV['HOME']"
        should_eval_as_eql_to "ENV['RUBYOPT']", '-ryaml' # changed with jruby.runtime.env
        # it was processed - feature got required :
        should_eval_as_eql_to "require 'yaml'", false
      end

      it "does a complete ENV clean including RUBYOPT" do
        set_config 'jruby.runtime.env', 'false'
        #set_config 'jruby.runtime.env.rubyopt', 'false'

        app_factory = app_factory_with_RUBYOPT '-ryaml'
        @runtime = app_factory.newRuntime

        should_eval_as_nil "ENV['HOME']"
        should_eval_as_nil "ENV['RUBYOPT']"
        should_eval_as_eql_to "require 'yaml'", true # -ryaml not processed
      end

      it "handles jruby.compat.version == '1.9' and starts in 1.9 mode" do
        set_config 'jruby.compat.version', '1.9'
        #@rack_config.stub(:getCompatVersion).and_return org.jruby.CompatVersion::RUBY1_9
        @runtime = app_factory.new_runtime
        @runtime.is1_9.should be_true
      end

      it "handles jruby.runtime.arguments == '-X+O -Ke' and start with object space enabled and KCode EUC" do
        set_config 'jruby.runtime.arguments', '-X+O -Ke'
        #@rack_config.stub(:getRuntimeArguments).and_return ['-X+O', '-Ke'].to_java(:String)
        @runtime = app_factory.new_runtime
        @runtime.object_space_enabled.should be_true
        @runtime.kcode.should == Java::OrgJrubyUtil::KCode::EUC
      end

      it "does not propagate ENV changes to JVM (and indirectly to other JRuby VM instances)" do
        runtime = app_factory.new_runtime

        java.lang.System.getenv['VAR1'].should be_nil
        #Nil returned from Ruby VM don't have the rspec decorations'
        nil.should {
          runtime.evalScriptlet("ENV['VAR1']").nil?
        }
        result = runtime.evalScriptlet("ENV['VAR1'] = 'VALUE1';")

        #String returned from Ruby VM don't have the rspec decorations'
        String.new(result).should == 'VALUE1'
        java.lang.System.getenv['VAR1'].should be_nil
      end

      private

      def app_factory_with_RUBYOPT(rubyopt = '-rubygems')
        app_factory =
          Class.new(org.jruby.rack.DefaultRackApplicationFactory) do

            def initialize(rubyopt); super(); @rubyopt = rubyopt; end

            def initRuntimeConfig(config)
              env = java.util.HashMap.new config.getEnvironment
              env.put 'RUBYOPT', @rubyopt
              config.setEnvironment env
              super
            end

          end.new(rubyopt)
        @rack_config = org.jruby.rack.DefaultRackConfig.new
        @rack_context.stub(:getConfig).and_return @rack_config
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
      @rack_context.stub(:getRealPath).and_return Dir::tmpdir
    end

    it "creates a Ruby object from the script snippet given" do
      @rack_config.should_receive(:getRackup).and_return("require 'rack/lobster'; Rack::Lobster.new")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      app_object = app_factory.newApplication
      app_object.respond_to?(:call).should == true
    end

    it "raises an exception if creation failed" do
      @rack_config.should_receive(:getRackup).and_return("raise 'something went wrong'")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      app_object = app_factory.newApplication
      begin
        app_object.init
        fail "expected to raise"
      rescue => e
        expect( e.message ).to eql 'something went wrong'
      end
    end
  end

  describe "getApplication" do
    it "creates an application and initializes it" do
      @rack_config.should_receive(:getRackup).and_return("raise 'init was called'")
      app_factory = mocked_runtime_application_factory
      app_factory.init @rack_context
      begin
        app_factory.getApplication
        fail "expected to raise"
      rescue => e
        expect( e.message ).to eql 'init was called'
      end
      #lambda { app_factory.getApplication }.should raise_error
    end
  end

  describe "finishedWithApplication" do
    it "should call destroy on the application object" do
      rack_app = double "application"
      rack_app.should_receive(:destroy)
      @app_factory.finishedWithApplication rack_app
    end
  end

  describe "destroy" do
    it "should call destroy on the error application" do
      rack_app = double "error app"
      rack_app.should_receive(:destroy)
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
      def createRackServletWrapper(runtime, rackup); end
    end
    @app_factory = klass.new

    @rack_context.should_receive(:getRealPath).with('/config.ru').and_return nil
    #@rack_context.should_receive(:getContextPath).and_return '/'
    @rack_config.should_receive(:getRackup).and_return nil
    @rack_config.should_receive(:getRackupPath).and_return nil

    @app_factory.init @rack_context

    @app_factory.should_receive(:createRackServletWrapper) do |runtime, rackup|
      runtime.should be JRuby.runtime
      rackup.should == "run JRuby::Rack::RailsBooter.to_app"
    end
    JRuby::Rack::RailsBooter.should_receive(:load_environment)

    @app_factory.createApplicationObject(JRuby.runtime)
    JRuby::Rack.booter.should be_a(JRuby::Rack::RailsBooter)
  end

end

describe org.jruby.rack.PoolingRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @pooling_factory = org.jruby.rack.PoolingRackApplicationFactory.new @factory
    @pooling_factory.context = @rack_context
  end

  it "should initialize the delegate factory when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    @pooling_factory.init(@rack_context)
  end

  it "should start out empty" do
    @pooling_factory.getApplicationPool.should be_empty
  end

  it "should create a new application when empty" do
    app = double "app"
    @factory.should_receive(:getApplication).and_return app
    @pooling_factory.getApplication.should == app
  end

  it "should not add newly created application to pool" do
    app = double "app"
    @factory.should_receive(:getApplication).and_return app
    @pooling_factory.getApplication.should == app
    @pooling_factory.getApplicationPool.to_a.should == []
  end

  it "accepts an existing application and puts it back in the pool" do
    app = double "app"
    @pooling_factory.getApplicationPool.to_a.should == []
    @pooling_factory.finishedWithApplication app
    @pooling_factory.getApplicationPool.to_a.should == [ app ]
    @pooling_factory.getApplication.should == app
  end

  it "calls destroy on all cached applications when destroyed" do
    app1, app2 = double("app1"), double("app2")
    @pooling_factory.finishedWithApplication app1
    @pooling_factory.finishedWithApplication app2
    @factory.should_receive(:finishedWithApplication).with(app1) # app1.should_receive(:destroy)
    @factory.should_receive(:finishedWithApplication).with(app2) # app2.should_receive(:destroy)
    @factory.should_receive(:destroy)

    @pooling_factory.destroy
    @pooling_factory.getApplicationPool.to_a.should == [] # and empty application pool
  end

  it "creates applications during initialization according to the jruby.min.runtimes context parameter" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 1
    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "does not allow new applications beyond the maximum specified by the jruby.max.runtimes context parameter" do
    @factory.stub(:init)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1

    @pooling_factory.init(@rack_context)
    @pooling_factory.finishedWithApplication double("app1")
    @pooling_factory.finishedWithApplication double("app2")
    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "does not add an application back into the pool if it already exists" do
    @factory.stub(:init)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 4
    @pooling_factory.init(@rack_context)
    rack_application_1 = double("app1")
    @pooling_factory.finishedWithApplication rack_application_1
    @pooling_factory.finishedWithApplication rack_application_1

    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "forces the maximum size to be greater or equal to the initial size" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 2
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1

    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should == 2
    @pooling_factory.finishedWithApplication double("app")
    @pooling_factory.getApplicationPool.size.should == 2
  end

  it "retrieves the error application from the delegate factory" do
    app = double("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @pooling_factory.getErrorApplication.should == app
  end

  it "waits till initial runtimes get initialized (with wait set to true)" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return do
        sleep(0.10)
      end
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return true
    @rack_config.should_receive(:getInitialRuntimes).and_return 4
    @rack_config.should_receive(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should >= 4
  end

  it "throws an exception from getApplication when an app failed to initialize " +
     "(even when only a single application initialization fails)" do
    @factory.stub(:init)
    app_count = java.util.concurrent.atomic.AtomicInteger.new(0)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return do
        if app_count.addAndGet(1) == 2
          raise org.jruby.rack.RackInitializationException.new('failed app init')
        end
        sleep(0.05)
      end
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    @rack_config.should_receive(:getInitialRuntimes).and_return 3
    @rack_config.should_receive(:getMaximumRuntimes).and_return 3

    @pooling_factory.init(@rack_context)
    sleep(0.20)

    failed = 0
    3.times do
      begin
        @pooling_factory.getApplication
      rescue org.jruby.rack.RackInitializationException
        failed += 1
      end
    end
    if failed != 3
      fail "@pooling_factory.getApplication expected to fail once, but failed #{failed}-time(s)"
    end
  end

  it "wait until pool is filled when invoking getApplication (with wait set to false)" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return { sleep(0.2) }
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    @rack_config.should_receive(:getInitialRuntimes).and_return 3
    @rack_config.should_receive(:getMaximumRuntimes).and_return 4

    @pooling_factory.init(@rack_context)
    millis = java.lang.System.currentTimeMillis
    @pooling_factory.getApplication.should_not be nil
    millis = java.lang.System.currentTimeMillis - millis
    millis.should >= 150 # getApplication waited ~ 0.2 secs
  end

  it "waits acquire timeout till an application is available from the pool (than raises)" do
    @factory.stub(:init)
    @factory.should_receive(:newApplication).twice.and_return do
      app = double "app"
      app.should_receive(:init).and_return { sleep(0.2) }
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    @rack_config.should_receive(:getInitialRuntimes).and_return 2
    @rack_config.should_receive(:getMaximumRuntimes).and_return 2

    @pooling_factory.init(@rack_context)
    @pooling_factory.acquire_timeout = 1.to_java # second
    millis = java.lang.System.currentTimeMillis
    @pooling_factory.getApplication.should_not be nil
    millis = java.lang.System.currentTimeMillis - millis
    millis.should >= 150 # getApplication waited ~ 0.2 secs

    app2 = @pooling_factory.getApplication # now the pool is empty

    @pooling_factory.acquire_timeout = 0.1.to_java # second
    millis = java.lang.System.currentTimeMillis
    lambda { @pooling_factory.getApplication }.should raise_error(org.jruby.rack.AcquireTimeoutException)
    millis = java.lang.System.currentTimeMillis - millis
    millis.should >= 90 # waited about ~ 0.1 secs

    @pooling_factory.finishedWithApplication(app2) # gets back to the pool
    lambda { @pooling_factory.getApplication.should == app2 }.should_not raise_error
  end

  it "gets and initializes new applications until maximum allows to create more" do
    @factory.stub(:init)
    @factory.should_receive(:newApplication).twice.and_return do
      app = double "app (new)"
      app.should_receive(:init).and_return { sleep(0.1) }
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    @rack_config.stub(:getInitialRuntimes).and_return 2
    @rack_config.stub(:getMaximumRuntimes).and_return 4

    @pooling_factory.init(@rack_context)
    @pooling_factory.acquire_timeout = 0.10.to_java # second

    lambda {
      2.times { @pooling_factory.getApplication.should_not be nil }
    }.should_not raise_error

    @factory.should_receive(:getApplication).twice.and_return do
      app = double "app (get)"; sleep(0.15); app
    end

    millis = java.lang.System.currentTimeMillis
    lambda {
      2.times { @pooling_factory.getApplication.should_not be nil }
    }.should_not raise_error
    millis = java.lang.System.currentTimeMillis - millis
    millis.should >= 300 # waited about 2 x 0.15 secs

    millis = java.lang.System.currentTimeMillis
    lambda {
      @pooling_factory.getApplication
    }.should raise_error(org.jruby.rack.AcquireTimeoutException)
    millis = java.lang.System.currentTimeMillis - millis
    millis.should >= 90 # waited about ~ 0.10 secs
  end

  it "initializes initial runtimes in paralel (with wait set to false)" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return do
        sleep(0.15)
      end
      app
    end
    @rack_config.stub(:getBooleanProperty).with("jruby.runtime.init.wait").and_return false
    @rack_config.stub(:getInitialRuntimes).and_return 6
    @rack_config.stub(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should < 6
    sleep(0.45) # 6 x 0.15 == 0.9 but we're booting in paralel
    @pooling_factory.getApplicationPool.size.should >= 6

    expect( @pooling_factory.getManagedApplications ).to_not be_empty
    expect( @pooling_factory.getManagedApplications.size ).to eql 6
  end

  it "throws from init when application initialization in thread failed" do
    @factory.stub(:init)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return do
        sleep(0.05); raise "app.init raising"
      end
      app
    end
    @rack_config.stub(:getInitialRuntimes).and_return 2
    @rack_config.stub(:getMaximumRuntimes).and_return 2

    raise_error_logged = 0
    @rack_context.stub(:log).with do |level, msg, e|
      if level == 'ERROR'
        expect( msg ).to eql 'unable to initialize application'
        expect( e ).to be_a org.jruby.exceptions.RaiseException
        raise_error_logged += 1
      else
        true
      end
    end

    expect(lambda {
      @pooling_factory.init(@rack_context)
    }).to raise_error org.jruby.rack.RackInitializationException
    expect( raise_error_logged ).to eql 1 # logs same init exception once

    # NOTE: seems it's not such a good idea to return empty on init error
    # expect( @pooling_factory.getManagedApplications ).to be_empty
  end

end

describe org.jruby.rack.SerialPoolingRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @pooling_factory = org.jruby.rack.SerialPoolingRackApplicationFactory.new @factory
    @pooling_factory.context = @rack_context
  end

  it "initializes initial runtimes in serial order" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub(:newApplication).and_return do
      app = double "app"
      app.stub(:init).and_return do
        sleep(0.05)
      end
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 6
    @rack_config.should_receive(:getMaximumRuntimes).and_return 8

    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should == 6
  end

end

describe org.jruby.rack.SharedRackApplicationFactory do

  before :each do
    @factory = double "factory"
    @shared_factory = org.jruby.rack.SharedRackApplicationFactory.new @factory
  end

  it "initializes the delegate factory and creates the (shared) application when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.should_receive(:getApplication).and_return app = double("application")
    @shared_factory.init(@rack_context)

    expect( @shared_factory.getManagedApplications ).to_not be_empty
    expect( @shared_factory.getManagedApplications.size ).to eql 1
    expect( @shared_factory.getManagedApplications.to_a[0] ).to be app
  end

  it "throws an exception if the shared application cannot be initialized " do
    @factory.should_receive(:init).with(@rack_context)
    @factory.should_receive(:getApplication).and_raise java.lang.ArithmeticException.new('42')

    @rack_context.should_receive(:log).with do |level, msg, e|
      if level == 'ERROR'
        expect( e ).to be_a java.lang.ArithmeticException
      else
        true
      end
    end

    begin
      @shared_factory.init(@rack_context)
    rescue org.jruby.rack.RackInitializationException => e
      e = unwrap_native_exception(e)
      expect( e.message ).to eql 'java.lang.ArithmeticException: 42'
    else
      fail "expected to rescue RackInitializationException"
    end

    expect( @shared_factory.getManagedApplications ).to be_empty
  end

  it "throws initialization exception on each getApplication call if init failed" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.should_receive(:getApplication).and_raise java.lang.RuntimeException.new('42')
    @factory.should_not_receive(:getErrorApplication) # dispacther invokes this ...

    begin
      @shared_factory.init(@rack_context)
    rescue java.lang.RuntimeException => e
      # NOOP
    end
    expect( lambda {
      @shared_factory.getApplication
    }).to raise_error(org.jruby.rack.RackInitializationException)
  end

  it "returns the same application for any newApplication or getApplication call" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.should_receive(:getApplication).and_return app = double("application")
    @shared_factory.init(@rack_context)
    1.upto(5) do
      @shared_factory.newApplication.should == app
      @shared_factory.getApplication.should == app
      @shared_factory.finishedWithApplication app
    end
  end

  it "finished with application using delegate factory when destroyed" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.should_receive(:getApplication).and_return app = double("application")
    @factory.should_receive(:destroy)
    @factory.should_receive(:finishedWithApplication).with(app)
    @shared_factory.init(@rack_context)
    @shared_factory.destroy
  end

  it "retrieves the error application from the delegate factory" do
    @factory.should_receive(:getErrorApplication).and_return app = double("error app")
    @shared_factory.getErrorApplication.should == app
  end

end