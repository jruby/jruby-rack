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
    
    application = DefaultRackApplication.new(ruby_object)
    application.call(servlet_request).should == rack_result
  end
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory, "newRuntime" do
  it "should create a new Ruby runtime with the rack environment pre-loaded" do
    app_factory = DefaultRackApplicationFactory.new
    runtime = app_factory.newRuntime
    lazy_string = proc {|v| "(begin; #{v}; rescue Exception => e; e.class; end).name"}
    app_factory.verify(runtime, lazy_string.call("Rack")).should == "Rack"
    app_factory.verify(runtime, lazy_string.call("Rack::Handler::Servlet")
      ).should == "Rack::Handler::Servlet"
    app_factory.verify(runtime, lazy_string.call("Rack::Handler::Bogus")
      ).should_not == "Rack::Handler::Bogus"
  end
end

describe DefaultRackApplicationFactory, "newApplication" do
  it "should create a Ruby object from the script snippet given" do
    servlet_context = mock("servlet context")
    servlet_context.stub!(:getInitParameter).and_return("require 'rack/lobster'; Rack::Lobster.new")
    app_factory = DefaultRackApplicationFactory.new
    app_factory.init(servlet_context)
    object = app_factory.newApplication
    object.respond_to?(:call).should == true
  end
end

import org.jruby.rack.rails.RailsRackApplicationFactory

describe RailsRackApplicationFactory, "init" do
  before :each do
    @servlet_context = mock("servlet context")
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
    @app_factory = RailsRackApplicationFactory.new
  end
  
  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    @app_factory.init(@servlet_context)
    @app_factory.rails_root.should == "./WEB-INF"
  end

  it "should default RAILS_ROOT to /WEB-INF" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    @app_factory.init(@servlet_context)
    @app_factory.rails_root.should == "./WEB-INF"
  end

  it "should determine RAILS_ENV from the 'rails.env' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("rails.env").and_return "test"
    @app_factory.init(@servlet_context)    
    @app_factory.rails_env.should == "test"
  end

  it "should default RAILS_ENV to 'production'" do
    @app_factory.init(@servlet_context)    
    @app_factory.rails_env.should == "production"
  end
end

describe RailsRackApplicationFactory, "newRuntime" do
  before :each do
    @servlet_context = mock("servlet context")
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
    @app_factory = RailsRackApplicationFactory.new
    @app_factory.init(@servlet_context)
  end

  it "should initialize ENV['RAILS_ENV'] and ENV['RAILS_ROOT']" do
    runtime = @app_factory.newRuntime
    lazy_env = proc {|v| "ENV['#{v}']"}
    @app_factory.verify(runtime, lazy_env.call("RAILS_ENV")).should == "production"
    @app_factory.verify(runtime, lazy_env.call("RAILS_ROOT")).should == "/"
  end
end