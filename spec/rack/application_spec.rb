#--
# **** BEGIN LICENSE BLOCK *****
# Version: CPL 1.0/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Common Public
# License Version 1.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.eclipse.org/legal/cpl-v10.html
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# Copyright (C) 2007 Sun Microsystems, Inc.
#
# Alternatively, the contents of this file may be used under the terms of
# either of the GNU General Public License Version 2 or later (the "GPL"),
# or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
# in which case the provisions of the GPL or the LGPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of either the GPL or the LGPL, and not to allow others to
# use your version of this file under the terms of the CPL, indicate your
# decision by deleting the provisions above and replace them with the notice
# and other provisions required by the GPL or the LGPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the CPL, the GPL or the LGPL.
# **** END LICENSE BLOCK ****
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.DefaultRackApplication

describe DefaultRackApplication, "call" do
  it "should invoke the call method on the ruby object and return the rack result" do
    servlet_request = mock("servlet request")
    rack_result = org.jruby.rack.RackResult.impl {}

    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(servlet_request).and_return rack_result

    application = DefaultRackApplication.new
    application.setApplication(ruby_object)
    application.call(servlet_request).should == rack_result
  end
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory do
  before :each do
    @app_factory = DefaultRackApplicationFactory.new
  end

  describe "newRuntime" do
    before :each do
      @servlet_context.stub!(:getInitParameter).and_return nil
      @app_factory.init @servlet_context
    end

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

  describe "newApplication" do
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
    it "should do nothing, since it does not cache runtimes" do
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