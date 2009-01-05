#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'

import org.jruby.rack.rails.RailsRackApplicationFactory

describe RailsRackApplicationFactory, "getApplication" do
  it "should load the Rails environment and return an application" do
    @app_factory = RailsRackApplicationFactory.new
    @rack_context.stub!(:getInitParameter).and_return nil
    @rack_context.stub!(:getRealPath).and_return Dir.pwd
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return("rails/root")
    @rack_context.should_receive(:getRealPath).with("rails/root").and_return(
      File.dirname(__FILE__) + '/../../rails')
    @app_factory.init(@rack_context)
    app = @app_factory.getApplication
    app.should respond_to(:call)
  end
end
