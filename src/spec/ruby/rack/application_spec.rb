#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.DefaultRackApplication

describe DefaultRackApplication, "call" do
  it "should invoke the call method on the ruby object and return the rack response" do
    servlet_request = mock("servlet request")
    rack_response = org.jruby.rack.RackResponse.impl {}

    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(servlet_request).and_return rack_response

    application = DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(servlet_request).should == rack_response
  end
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory do
  before :each do
    @app_factory = DefaultRackApplicationFactory.new
  end

  describe do
    before :each do
      @servlet_context.stub!(:getInitParameter).and_return nil
      @app_factory.init @servlet_context
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
      @servlet_context.stub!(:getRealPath).and_return Dir::tmpdir
    end

    it "should create a Ruby object from the script snippet given" do
      @servlet_context.stub!(:getInitParameter).and_return("require 'rack/lobster'; Rack::Lobster.new")
      @app_factory.init @servlet_context
      object = @app_factory.newApplication
      object.respond_to?(:call).should == true
    end

    it "should raise an exception if creation failed" do
      @servlet_context.stub!(:getInitParameter).and_return("raise 'something went wrong'")
      @app_factory.init @servlet_context
      object = @app_factory.newApplication
      lambda { object.init }.should raise_error
    end

    it "should change directories to /WEB-INF during application initialization" do
      @servlet_context.should_receive(:getInitParameter).with("rackup").and_return(
        %{class Rack::Handler::Servlet; alias_method :create_env, :create_lazy_env; end;
          pwd = Dir.pwd; run(Proc.new { [200, {'Pwd' => pwd}, ['']] })})
      @app_factory.init @servlet_context
      object = @app_factory.newApplication
      object.init
      # Using mocks inside of another runtime breaks badly...trust me, this is the best way
      servlet_env = Object.new
      def servlet_env.method_missing(meth, *args,&block)
        case meth.to_sym
        when :to_io: StringIO.new
        when :getAttributeNames, :getHeaderNames: []
        when :getServerPort, :getContentType: 0
        when :getContentType: "text/html"
        else
          nil
        end
      end
      response = object.__call(servlet_env)
      io = StringIO.new
      # more inter-runtime weirdness -- can't access the result string directly
      # printing it to an object in this runtime works though
      io.print(response.getHeaders['Pwd'])
      object.destroy
      io.string.should == Dir.chdir(Dir::tmpdir) { Dir.pwd }
    end
  end

  describe "getApplication" do
    it "should create an application and initialize it" do
      @servlet_context.stub!(:getInitParameter).and_return("raise 'init was called'")
      @app_factory.init @servlet_context
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
    @factory.should_receive(:init).with(@servlet_context)
    @servlet_context.stub!(:getInitParameter).and_return nil
    @pool.init(@servlet_context)
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
  to the jruby.initial.runtimes context parameter" do
    @factory.should_receive(:init).with(@servlet_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.should_receive(:getInitParameter).with("jruby.initial.runtimes").and_return "1"
    @pool.init(@servlet_context)
    @pool.getApplicationPool.size.should == 1
  end

  it "should not create any new applications beyond the maximum specified
  by the jruby.max.runtimes context parameter" do
    @factory.should_receive(:init).with(@servlet_context)
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "1"
    @pool.init(@servlet_context)
    @pool.finishedWithApplication mock("app1")
    @pool.finishedWithApplication mock("app2")
    @pool.getApplicationPool.size.should == 1
  end

  it "should also recognize the jruby.pool.minIdle and jruby.pool.maxActive parameters from Goldspike" do
    @factory.should_receive(:init).with(@servlet_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.should_receive(:getInitParameter).with("jruby.pool.minIdle").and_return "1"
    @servlet_context.should_receive(:getInitParameter).with("jruby.pool.maxActive").and_return "2"
    @pool.init(@servlet_context)
    @pool.getApplicationPool.size.should == 1
    @pool.finishedWithApplication mock("app")
    @pool.getApplicationPool.size.should == 2
  end

  it "should force the maximum size to be greater or equal to the initial size" do
    @factory.should_receive(:init).with(@servlet_context)
    @factory.stub!(:newApplication).and_return do
      app = mock "app"
      app.should_receive(:init)
      app
    end
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.should_receive(:getInitParameter).with("jruby.initial.runtimes").and_return "2"
    @servlet_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "1"
    @pool.init(@servlet_context)
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
    @factory.should_receive(:init).with(@servlet_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared.init(@servlet_context)
  end

  it "should throw a servlet exception if the shared application cannot be initialized" do
    @factory.should_receive(:init).with(@servlet_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_raise org.jruby.rack.RackInitializationException.new(nil)
    lambda {
      @shared.init(@servlet_context)
    }.should raise_error # TODO: doesn't work w/ raise_error(javax.servlet.ServletException)
  end

  it "should return the same application for any newApplication or getApplication call" do
    @factory.should_receive(:init).with(@servlet_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    @shared.init(@servlet_context)
    1.upto(5) do
      @shared.newApplication.should == app
      @shared.getApplication.should == app
      @shared.finishedWithApplication app
    end
  end

  it "should call destroy on the shared application when destroyed" do
    @factory.should_receive(:init).with(@servlet_context)
    app = mock "application"
    @factory.should_receive(:getApplication).and_return app
    app.should_receive(:destroy)
    @shared.init(@servlet_context)
    @shared.destroy
  end

  it "should retrieve the error application from the delegate factory" do
    app = mock("app")
    @factory.should_receive(:getErrorApplication).and_return app
    @shared.getErrorApplication.should == app
  end
end