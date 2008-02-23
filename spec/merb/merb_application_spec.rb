require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.merb.MerbRackApplicationFactory

describe MerbRackApplicationFactory, "getApplication" do
  before :each do
    @app_factory = MerbRackApplicationFactory.new
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return Dir.pwd
    @app_factory.init(@servlet_context)
    @merb_root = File.dirname(__FILE__) + '/../../src/test/resources/merb'
  end
   
  it "should load the Merb environment and return an application" do
    @servlet_context.should_receive(:getInitParameter).
      with("merb.root").and_return("merb/root")
    @servlet_context.should_receive(:getRealPath).
      with("merb/root").and_return(@merb_root)
    app = @app_factory.getApplication
    app.should respond_to(:call)
  end  
end