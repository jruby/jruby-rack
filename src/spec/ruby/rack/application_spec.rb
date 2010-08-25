#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.DefaultRackApplication

require 'jruby/rack/environment'

describe DefaultRackApplication, "call" do
  it "should invoke the call method on the ruby object and return the rack response" do
    server_request = mock("server request")
    server_request.stub!(:getInput).and_return(StubInputStream.new("hello"))
    server_request.stub!(:getContentLength).and_return(-1)
    rack_response = org.jruby.rack.RackResponse.impl {}

    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(server_request).and_return do |servlet_env|
      servlet_env.to_io.read.should == "hello"
      rack_response
    end

    application = DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(server_request).should == rack_response
  end
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory do
  before :each do
    @app_factory = DefaultRackApplicationFactory.new
  end

  it "should receive a rackup script via the 'rackup' parameter" do
    @rack_context.should_receive(:getInitParameter).with('rackup').and_return 'run MyRackApp'
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a rackup script via the 'rackup.path' parameter" do
    @rack_context.should_receive(:getInitParameter).with('rackup.path').and_return '/WEB-INF/hello.ru'
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').and_return StubInputStream.new("run MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == 'run MyRackApp'
  end

  it "should look for a config.ru rackup script below /WEB-INF" do
    @rack_context.should_receive(:getResourcePaths).with('/WEB-INF/').and_return(
      java.util.HashSet.new(%w(app/ config/ config.ru lib/ vendor/).map{|f| "/WEB-INF/#{f}"}))
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
    @rack_context.should_receive(:getInitParameter).with('rackup.path').and_return '/WEB-INF/hello.ru'
    @rack_context.should_receive(:getResourceAsStream).with('/WEB-INF/hello.ru').and_return StubInputStream.new("# coding: us-ascii\nrun MyRackApp")
    @app_factory.init @rack_context
    @app_factory.rackup_script.should == "# coding: us-ascii\nrun MyRackApp"
  end

  describe "" do
    before :each do
      @rack_context.stub!(:getInitParameter).and_return nil
      @rack_context.stub!(:getResourcePaths).and_return nil
      @app_factory.init @rack_context
    end

    describe "init" do
      it "should create an error application" do
        @app_factory.getErrorApplication.should respond_to(:call)
      end
    end

    describe "newRuntime" do
      it "should create a new Ruby runtime with the rack environment pre-loaded" do
        runtime = @app_factory.newRuntime
        lazy_string = proc {|v| "(begin; #{v}; rescue Exception => e; e.class; end).name"}
        @app_factory.verify(runtime, lazy_string.call("Rack")).should == "Rack"
        @app_factory.verify(runtime, lazy_string.call("Rack::Handler::Servlet")
        ).should == "Rack::Handler::Servlet"
        @app_factory.verify(runtime, lazy_string.call("Rack::Handler::Bogus")
        ).should_not == "Rack::Handler::Bogus"
      end

      it "should initialize the $servlet_context global variable" do
        runtime = @app_factory.newRuntime
        @app_factory.verify(runtime, "defined?($servlet_context)").should_not be_empty
      end
    end
  end

  describe "newApplication" do
    before :each do
      require 'tempfile'
      @rack_context.stub!(:getRealPath).and_return Dir::tmpdir
    end

    it "should create a Ruby object from the script snippet given" do
      @rack_context.should_receive(:getInitParameter).with('rackup').and_return("require 'rack/lobster'; Rack::Lobster.new")
      @app_factory.init @rack_context
      object = @app_factory.newApplication
      object.respond_to?(:call).should == true
    end

    it "should raise an exception if creation failed" do
      @rack_context.should_receive(:getInitParameter).with('rackup').and_return("raise 'something went wrong'")
      @app_factory.init @rack_context
      object = @app_factory.newApplication
      lambda { object.init }.should raise_error
    end
  end

  describe "getApplication" do
    it "should create an application and initialize it" do
      @rack_context.should_receive(:getInitParameter).with('rackup').and_return("raise 'init was called'")
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
    @pool.destroy
  end

  it "should create applications during initialization according 
  to the jruby.min.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_context.should_receive(:getInitParameter).with("jruby.min.runtimes").and_return "1"
    @pool.init(@rack_context)
    @pool.getApplicationPool.size.should == 1
  end

  it "should not create any new applications beyond the maximum specified
  by the jruby.max.runtimes context parameter" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "1"
    @pool.init(@rack_context)
    @pool.finishedWithApplication mock("app1")
    @pool.finishedWithApplication mock("app2")
    @pool.getApplicationPool.size.should == 1
  end

  it "should not add an application back into the pool if it already exists" do
    @factory.should_receive(:init).with(@rack_context)
    @rack_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "4"
    @pool.init(@rack_context)
    rack_application_1 = mock("app1")
    @pool.finishedWithApplication rack_application_1
    @pool.finishedWithApplication rack_application_1
    @pool.getApplicationPool.size.should == 1
  end

  it "should also recognize the jruby.pool.minIdle and jruby.pool.maxActive parameters from Goldspike" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_context.should_receive(:getInitParameter).with("jruby.pool.minIdle").and_return "1"
    @rack_context.should_receive(:getInitParameter).with("jruby.pool.maxActive").and_return "2"
    @pool.init(@rack_context)
    @pool.getApplicationPool.size.should == 1
    @pool.finishedWithApplication mock("app")
    @pool.getApplicationPool.size.should == 2
  end

  it "should force the maximum size to be greater or equal to the initial size" do
    @factory.should_receive(:init).with(@rack_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @rack_context.should_receive(:getInitParameter).with("jruby.min.runtimes").and_return "2"
    @rack_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "1"
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
