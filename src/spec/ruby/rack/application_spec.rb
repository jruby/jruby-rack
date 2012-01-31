#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

require 'jruby/rack/environment'

import org.jruby.rack.DefaultRackApplication

describe DefaultRackApplication, "call" do
  
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

    application = DefaultRackApplication.new
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

    application = DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(@rack_env)
  end
  
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory do
  
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
  
  it "should init and create application object without a rackup script" do
    # NOTE: a workaround to be able to mock it :
    klass = Class.new(DefaultRackApplicationFactory) do
      def createRackServletWrapper(runtime, rackup); end
    end
    @app_factory = klass.new
    
    @rack_context.stub!(:getRealPath).and_return nil
    @rack_config.should_receive(:getRackup).and_return nil
    @rack_config.should_receive(:getRackupPath).and_return nil
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == nil
    
    @rack_context.should_receive(:log).with do |msg|
      msg.should =~ /WARNING.*/
    end
    
    @app_factory.should_receive(:createRackServletWrapper) do |runtime, rackup|
      runtime && rackup.should == ""
    end

    runtime = @app_factory.newRuntime
    @app_factory.createApplicationObject(runtime)
  end
  
  context "initialized" do
    
    before :each do
      @rack_context.stub!(:getInitParameter).and_return nil
      @rack_context.stub!(:getResourcePaths).and_return nil
    end
    
    let(:app_factory) { @app_factory.init @rack_context; @app_factory }

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
      
      it "should initialize the $servlet_context global variable" do
        @runtime = app_factory.new_runtime
        should_not_eval_as_nil "defined?($servlet_context)"
      end

      it "should handle jruby.compat.version == '1.9' and start up in 1.9 mode" do
        @rack_config.stub!(:getCompatVersion).and_return org.jruby.CompatVersion::RUBY1_9
        @runtime = app_factory.new_runtime
        @runtime.is1_9.should be_true
      end

      it "should have environment variables cleared if the configuration ignores the environment" do
        ENV["HOME"].should_not == ""
        @rack_config.stub!(:isIgnoreEnvironment).and_return true
        @runtime = app_factory.new_runtime
        should_eval_as_nil "ENV['HOME']"
      end

      it "should handle jruby.runtime.arguments == '-X+O -Ke' and start with object space enabled and KCode EUC" do
        @rack_config.stub!(:getRuntimeArguments).and_return ['-X+O', '-Ke'].to_java(:String)
        @runtime = app_factory.new_runtime
        @runtime.object_space_enabled.should be_true
        @runtime.kcode.should == Java::OrgJrubyUtil::KCode::EUC
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

import org.jruby.rack.rails.RailsRackApplicationFactory

describe RailsRackApplicationFactory do
  
  before :each do
    @app_factory = RailsRackApplicationFactory.new
  end
  
  it "should init and create application object" do
    # NOTE: a workaround to be able to mock it :
    klass = Class.new(RailsRackApplicationFactory) do
      def createRackServletWrapper(runtime, rackup); end
    end
    @app_factory = klass.new
    
    @rack_context.stub!(:getRealPath).and_return nil
    @rack_config.should_receive(:getRackup).and_return nil
    @rack_config.should_receive(:getRackupPath).and_return nil
    
    @app_factory.init @rack_context
    
    @app_factory.should_receive(:createRackServletWrapper) do |runtime, rackup|
      runtime.should_not be_nil
      rackup.should == "run JRuby::Rack::RailsFactory.new"
    end

    runtime = @app_factory.newRuntime
    @app_factory.createApplicationObject(runtime)
  end
  
end

import org.jruby.rack.PoolingRackApplicationFactory

describe PoolingRackApplicationFactory do
  before :each do
    @factory = mock "factory"
    @pool = PoolingRackApplicationFactory.new @factory
  end

  it "should initialize the delegate factory when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    @pool.init(@rack_context)
  end

  it "should start out empty" do
    @pool.getApplicationPool.should be_empty
  end

  it "should create a new application when empty" do
    app = mock "app"
    @factory.should_receive(:getApplication).and_return app
    @pool.getApplication.should == app
  end

  it "should accept an existing application and put it back in the pool" do
    app = mock "app"
    @pool.getApplicationPool.should be_empty
    @pool.finishedWithApplication app
    @pool.getApplicationPool.should_not be_empty
    @pool.getApplication.should == app
  end

  it "should call destroy on all cached applications when destroyed" do
    app1 = mock "app1"
    app2 = mock "app2"
    @pool.finishedWithApplication app1
    @pool.finishedWithApplication app2
    app1.should_receive(:destroy)
    app2.should_receive(:destroy)
    @factory.should_receive(:destroy)
    @pool.destroy
  end

  it "should create applications during initialization according to the jruby.min.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 1
    @pool.init(@rack_context)
    @pool.getApplicationPool.size.should == 1
  end

  it "should not create any new applications beyond the maximum specified by the jruby.max.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1
    @pool.init(@rack_context)
    @pool.finishedWithApplication mock("app1")
    @pool.finishedWithApplication mock("app2")
    @pool.getApplicationPool.size.should == 1
  end

  it "should not add an application back into the pool if it already exists" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_config.should_receive(:getMaximumRuntimes).and_return 4
    @pool.init(@rack_context)
    rack_application_1 = mock("app1")
    @pool.finishedWithApplication rack_application_1
    @pool.finishedWithApplication rack_application_1
    @pool.getApplicationPool.size.should == 1
  end

  it "should force the maximum size to be greater or equal to the initial size" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_config.should_receive(:getInitialRuntimes).and_return 2
    @rack_config.should_receive(:getMaximumRuntimes).and_return 1
    @pool.init(@rack_context)
    @pool.waitForNextAvailable(30)
    @pool.getApplicationPool.size.should == 2
    @pool.finishedWithApplication mock("app")
    @pool.getApplicationPool.size.should == 2
  end

  it "should retrieve the error application from the delegate factory" do
    app = mock("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @pool.getErrorApplication.should == app
  end
end

import org.jruby.rack.SharedRackApplicationFactory

describe SharedRackApplicationFactory do
  before :each do
    @factory = mock "factory"
    @shared = SharedRackApplicationFactory.new @factory
  end

  it "should initialize the delegate factory and create the shared application when initialized" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared.init(@rack_context)
  end

  it "should throw a servlet exception if the shared application cannot be initialized" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
    lambda {
      @shared.init(@rack_context)
    }.should raise_error # TODO: doesn't work w/ raise_error(javax.servlet.ServletException)
  end

  it "should return a valid application object even if initialization fails" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
    @shared.init(@rack_context) rescue nil
    @shared.getApplication.should_not be_nil
  end

  it "should return the same application for any newApplication or getApplication call" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared.init(@rack_context)
    1.upto(5) do
      @shared.newApplication.should == app
      @shared.getApplication.should == app
      @shared.finishedWithApplication app
    end
  end

  it "should call destroy on the shared application when destroyed" do
    @factory.should_receive(:init).with(@rack_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @factory.should_receive(:destroy)
    app.should_receive(:destroy)
    @shared.init(@rack_context)
    @shared.destroy
  end

  it "should retrieve the error application from the delegate factory" do
    app = mock("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @shared.getErrorApplication.should == app
  end
end
