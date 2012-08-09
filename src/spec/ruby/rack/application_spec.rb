#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')
require 'jruby/rack/environment'

describe org.jruby.rack.DefaultRackApplication, "call" do
  
  before :each do
    @rack_env = mock("rack_request_env")
    @rack_env.stub!(:getContext).and_return @rack_context
    @rack_env.stub!(:getInput).and_return(StubInputStream.new("hello world!"))
    @rack_env.stub!(:getContentLength).and_return(12)
    @rack_response = org.jruby.rack.RackResponse.impl {}
  end
  
  it "should invoke the call method on the ruby object and return rack response" do
    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(@rack_env).and_return do |servlet_env|
      servlet_env.to_io.read.should == "hello world!"
      @rack_response
    end

    application = org.jruby.rack.DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(@rack_env).should == @rack_response
  end

  context "with filter setup (using captures)" do
    
    before :each do
      servlet_context = mock("servlet_context")
      servlet_context.stub!(:getInitParameter).and_return do |name|
        name && nil # return null
      end
      
      @servlet_request = org.jruby.rack.mock.MockHttpServletRequest.new(servlet_context)
      @servlet_response = org.jruby.rack.mock.MockHttpServletResponse.new

      rack_config = org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
      rack_context = org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
      request_capture = org.jruby.rack.servlet.RequestCapture.new(@servlet_request, rack_config)
      response_capture = org.jruby.rack.servlet.ResponseCapture.new(@servlet_response)

      @rack_env = org.jruby.rack.servlet.ServletRackEnvironment.new(request_capture, response_capture, rack_context)
    end
    
    it "should rewind body" do
      it_should_rewind_body
    end
    
  end
  
  context "with servlet setup (no captures)" do
    
    before :each do
      servlet_context = mock("servlet_context")
      servlet_context.stub!(:getInitParameter).and_return do |name|
        name && nil # return null
      end
      
      @servlet_request = org.jruby.rack.mock.MockHttpServletRequest.new(servlet_context)
      @servlet_response = org.jruby.rack.mock.MockHttpServletResponse.new

      rack_config = org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
      rack_context = org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)

      @rack_env = org.jruby.rack.servlet.ServletRackEnvironment.new(@servlet_request, @servlet_response, rack_context)
    end
    
    it "should rewind body" do
      it_should_rewind_body
    end
    
  end
  
  def it_should_rewind_body
    content = "Answer to the Ultimate Question of Life, the Universe, and Everything ..." # ''
    #42.times { content << "Answer to the Ultimate Question of Life, the Universe, and Everything ...\n" }
    @servlet_request.setContent content.to_java_bytes

    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(@rack_env).and_return do |servlet_env|
      body = servlet_env.to_io

      body.read.should == content
      body.read.should == ""
      body.rewind
      body.read.should == content

      org.jruby.rack.RackResponse.impl {}
    end

    application = org.jruby.rack.DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(@rack_env)
  end
  
end

describe org.jruby.rack.DefaultRackApplicationFactory do
  
  java_import org.jruby.rack.DefaultRackApplicationFactory
  
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
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a config.ru rackup script below /WEB-INF" do
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ config.ru lib/ vendor/).map{|f| "/WEB-INF/#{f}"}))
    @rack_context.should_receive(:getRealPath).with('/WEB-INF/config.ru')
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/config.ru').and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a config.ru script in subdirectories of /WEB-INF" do
    @rack_context.stub!(:getResourcePaths).and_return java.util.HashSet.new
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ lib/ vendor/).map{|f| "/WEB-INF/#{f}"}))
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/lib/').and_return(
      java.util.HashSet.new(["/WEB-INF/lib/config.ru"]))
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/lib/config.ru').and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should handle config.ru files with a coding: pragma" do
    @rack_config.should_receive(:getRackupPath).and_return '/WEB-INF/hello.ru'
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').and_return StubInputStream.new("# coding: us-ascii\nrun MyRackApp")
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
  
  after :each do
    JRuby::Rack.booter = nil
    $servlet_context = nil
  end
  
  it "should init and create application object without a rackup script" do
    JRuby::Rack.booter = nil
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
  
  context "initialized" do
    
    before :each do
      @rack_context.stub!(:getInitParameter).and_return nil
      @rack_context.stub!(:getResourcePaths).and_return nil
    end
    
    let(:app_factory) { @app_factory.init(@rack_context); @app_factory }

    describe "init" do
      
      it "should create an error application" do
        app_factory.getErrorApplication.should respond_to(:call)
      end
      
    end

    describe "newRuntime" do
      
      it "should create a new Ruby runtime with the jruby-rack environment pre-loaded" do
        @runtime = app_factory.new_runtime
        should_not_eval_as_nil "defined?(::Rack)"
        should_not_eval_as_nil "defined?(::Rack::Handler::Servlet)"
        should_eval_as_nil "defined?(Rack::Handler::Bogus)"
      end

      it "should not require 'rack' (until booter is called)" do
        @runtime = app_factory.new_runtime
        should_eval_as_nil "defined?(::Rack::VERSION)"
      end

      it "should not load any features (until load path is adjusted)" do
        # due to incorrectly detected jruby.home some container e.g. WebSphere 8
        # fail if things such as 'fileutils' get required during runtime init !
        
        # TODO: WTF? JRuby magic - $LOADED_FEATURES seems to get "inherited" if
        # Ruby.newInstance(config) is called with the factory's defaultConfig,
        # but only if it's executed with bundler e.g. `bundle exec rake spec`
        #@runtime = app_factory.new_runtime
        @runtime = org.jruby.Ruby.newInstance
        app_factory.send :initializeRuntime, @runtime

        reject_files = 
          "p =~ /.jar$/ || " + 
          "p =~ /^builtin/ || " + 
          "p =~ /java.rb$/ || p =~ /jruby.rb$/ || " + 
          "p =~ /jruby\\/java.*.rb/ || " + 
          "p =~ /jruby\\/rack.*.rb/ || " + 
          "p =~ /rack\\/handler\\/servlet.rb$/"
        # TODO: fails with JRuby 1.7 as it has all kind of things loaded e.g. :
        # thread.rb, rbconfig.rb, java.rb, lib/ruby/shared/rubygems.rb etc
        should_eval_as_eql_to "$LOADED_FEATURES.reject { |p| #{reject_files} }", []
      end
      
      it "initializes the $servlet_context global variable" do
        @runtime = app_factory.new_runtime
        should_not_eval_as_nil "defined?($servlet_context)"
      end

      it "clears environment variables if the configuration ignores the environment" do
        ENV["HOME"].should_not == ""
        @rack_config.stub!(:isIgnoreEnvironment).and_return true
        @runtime = app_factory.new_runtime
        should_eval_as_nil "ENV['HOME']"
      end

      it "sets ENV['PATH'] to an empty string if the configuration ignores the environment" do
        ENV["PATH"].should_not be nil
        ENV["PATH"].should_not == ""
        @rack_config.stub!(:isIgnoreEnvironment).and_return true
        @runtime = app_factory.new_runtime
        should_eval_as_eql_to "ENV['PATH']", ''
      end
      
      it "handles jruby.compat.version == '1.9' and starts in 1.9 mode" do
        @rack_config.stub!(:getCompatVersion).and_return org.jruby.CompatVersion::RUBY1_9
        @runtime = app_factory.new_runtime
        @runtime.is1_9.should be_true
      end
      
      it "handles jruby.runtime.arguments == '-X+O -Ke' and start with object space enabled and KCode EUC" do
        @rack_config.stub!(:getRuntimeArguments).and_return ['-X+O', '-Ke'].to_java(:String)
        @runtime = app_factory.new_runtime
        @runtime.object_space_enabled.should be_true
        @runtime.kcode.should == Java::OrgJrubyUtil::KCode::EUC
      end

      it "should not propagate ENV changes to JVM (and indirectly to other JRuby VM instances)" do
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

    end
    
  end

  describe "newApplication" do
    before :each do
      @rack_context.stub!(:getRealPath).and_return Dir::tmpdir
    end

    it "should create a Ruby object from the script snippet given" do
      @rack_config.should_receive(:getRackup).and_return("require 'rack/lobster'; Rack::Lobster.new")
      @app_factory.init @rack_context
      object = @app_factory.newApplication
      object.respond_to?(:call).should == true
    end

    it "should raise an exception if creation failed" do
      @rack_config.should_receive(:getRackup).and_return("raise 'something went wrong'")
      @app_factory.init @rack_context
      object = @app_factory.newApplication
      lambda { object.init }.should raise_error
    end
  end

  describe "getApplication" do
    it "should create an application and initialize it" do
      @rack_config.should_receive(:getRackup).and_return("raise 'init was called'")
      @app_factory.init @rack_context
      lambda { @app_factory.getApplication }.should raise_error
    end
  end

  describe "finishedWithApplication" do
    it "should call destroy on the application object" do
      app = mock "application"
      app.should_receive(:destroy)
      @app_factory.finishedWithApplication app
    end
  end

  describe "destroy" do
    it "should call destroy on the error application" do
      app = mock "error app"
      app.should_receive(:destroy)
      @app_factory.setErrorApplication app
      @app_factory.destroy
    end
  end
end

describe org.jruby.rack.rails.RailsRackApplicationFactory do
  
  java_import org.jruby.rack.rails.RailsRackApplicationFactory
  
  before :each do
    @app_factory = RailsRackApplicationFactory.new
    $servlet_context = @servlet_context
  end
  
  after :each do
    $servlet_context = nil
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
  
  class Java::OrgJrubyRack::PoolingRackApplicationFactory
    field_writer :rackContext
  end
  
  before :each do
    @factory = mock "factory"
    @pooling_factory = org.jruby.rack.PoolingRackApplicationFactory.new @factory
    @pooling_factory.rackContext = @rack_context
  end

  it "should initialize the delegate factory when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    @pooling_factory.init(@rack_context)
  end

  it "should start out empty" do
    @pooling_factory.getApplicationPool.should be_empty
  end

  it "should create a new application when empty" do
    app = mock "app"
    @factory.should_receive(:getApplication).and_return app
    @pooling_factory.getApplication.should == app
  end

  it "should not add newly created application to pool" do
    app = mock "app"
    @factory.should_receive(:getApplication).and_return app
    @pooling_factory.getApplication.should == app
    @pooling_factory.getApplicationPool.to_a.should == []
  end
  
  it "accepts an existing application and puts it back in the pool" do
    app = mock "app"
    @pooling_factory.getApplicationPool.to_a.should == []
    @pooling_factory.finishedWithApplication app
    @pooling_factory.getApplicationPool.to_a.should == [ app ]
    @pooling_factory.getApplication.should == app
  end

  it "calls destroy on all cached applications when destroyed" do
    app1, app2 = mock("app1"), mock("app2")
    @pooling_factory.finishedWithApplication app1
    @pooling_factory.finishedWithApplication app2
    app1.should_receive(:destroy)
    app2.should_receive(:destroy)
    @factory.should_receive(:destroy)
    
    @pooling_factory.destroy
    @pooling_factory.getApplicationPool.to_a.should == [] # and empty application pool
  end
  
  it "creates applications during initialization according to the jruby.min.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 1
    @pooling_factory.init(@rack_context)
    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "does not allow new applications beyond the maximum specified by the jruby.max.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1
    @pooling_factory.init(@rack_context)
    @pooling_factory.finishedWithApplication mock("app1")
    @pooling_factory.finishedWithApplication mock("app2")
    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "does not add an application back into the pool if it already exists" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 4
    @pooling_factory.init(@rack_context)
    rack_application_1 = mock("app1")
    @pooling_factory.finishedWithApplication rack_application_1
    @pooling_factory.finishedWithApplication rack_application_1
    @pooling_factory.getApplicationPool.size.should == 1
  end

  it "forces the maximum size to be greater or equal to the initial size" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 2
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1
    @pooling_factory.init(@rack_context)
    # java.lang.Thread.yield
    @pooling_factory.send :waitForNextAvailable, 10 # seconds
    @pooling_factory.getApplicationPool.size.should == 2
    @pooling_factory.finishedWithApplication mock("app")
    @pooling_factory.getApplicationPool.size.should == 2
  end

  it "retrieves the error application from the delegate factory" do
    app = mock("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @pooling_factory.getErrorApplication.should == app
  end
  
  it "initializes initial runtimes in paralel" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.stub!(:init).and_return do
        sleep(0.25)
      end
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 6
    @rack_config.should_receive(:getMaximumRuntimes).and_return 8
    @pooling_factory.init(@rack_context)
    sleep(0.75) # 6 x 0.25 == 1.5 but we're booting in paralel
    @pooling_factory.getApplicationPool.size.should >= 6
  end
  
end

describe org.jruby.rack.SerialPoolingRackApplicationFactory do

  before :each do
    @factory = mock "factory"
    @pooling_factory = org.jruby.rack.SerialPoolingRackApplicationFactory.new @factory
    @pooling_factory.rackContext = @rack_context
  end
  
  it "initializes initial runtimes in serial order" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.stub!(:init).and_return do
        sleep(0.25)
      end
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 6
    @rack_config.should_receive(:getMaximumRuntimes).and_return 8
    @pooling_factory.init(@rack_context)
    sleep(0.75)
    @pooling_factory.getApplicationPool.size.should <= 6
    sleep(0.85)
    @pooling_factory.getApplicationPool.size.should == 6
  end
  
end

describe org.jruby.rack.SharedRackApplicationFactory do
  
  before :each do
    @factory = mock "factory"
    @shared_factory = org.jruby.rack.SharedRackApplicationFactory.new @factory
  end

  it "should initialize the delegate factory and create the shared application when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared_factory.init(@rack_context)
  end

  it "should throw a servlet exception if the shared application cannot be initialized" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_raise java.lang.RuntimeException.new('42')
    lambda {
      @shared_factory.init(@rack_context)
    }.should raise_error(org.jruby.rack.RackInitializationException)
  end

  it "should return a valid application object even if initialization fails" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_raise java.lang.RuntimeException.new('42')
    begin
      @shared_factory.init(@rack_context)
    rescue org.jruby.rack.RackInitializationException
    end
    @shared_factory.getApplication.should_not be nil
  end

  it "should return the same application for any newApplication or getApplication call" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared_factory.init(@rack_context)
    1.upto(5) do
      @shared_factory.newApplication.should == app
      @shared_factory.getApplication.should == app
      @shared_factory.finishedWithApplication app
    end
  end

  it "should call destroy on the shared application when destroyed" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @factory.should_receive(:destroy)
    app.should_receive(:destroy)
    @shared_factory.init(@rack_context)
    @shared_factory.destroy
  end

  it "should retrieve the error application from the delegate factory" do
    app = mock("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @shared_factory.getErrorApplication.should == app
  end
end
