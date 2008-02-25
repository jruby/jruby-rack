#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'

import org.jruby.rack.rails.RailsRackApplicationFactory

describe RailsRackApplicationFactory, "getApplication" do
  before :each do
    @app_factory = RailsRackApplicationFactory.new
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return Dir.pwd
    @app_factory.init(@servlet_context)
  end
  
  it "should load the Rails environment and return an application" do
    @servlet_context.should_receive(:getInitParameter).with("rails.root").and_return(
      "rails/root")
    @servlet_context.should_receive(:getRealPath).with("rails/root").and_return(
      File.dirname(__FILE__) + '/../../../src/test/resources/rails')
    app = @app_factory.getApplication
    app.should respond_to(:call)
  end
end