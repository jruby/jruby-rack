require File.dirname(__FILE__) + '/../../spec_helper'
require 'rack/adapter/servlet_helper'

describe Rack::Adapter::ServletHelper do
  before :each do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = Rack::Adapter::ServletHelper.new @servlet_context
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should default public root to '/WEB-INF/public'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/public").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should determine the gem path from the gem.path init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/gems").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should set Gem.path to the value of gem_path" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/gems").and_return "/blah"
    create_helper
    Gem.path.should include('/blah')
  end

  it "should create a Logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end
end