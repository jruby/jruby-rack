require File.dirname(__FILE__) + '/../../../spec_helper'
require 'rack/adapter/merb/servlet_helper'

describe Rack::Adapter::MerbServletHelper do
  before :each do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = Rack::Adapter::MerbServletHelper.new @servlet_context
  end
  
  it "should determine merb_root from the 'merb.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("merb.root").and_return "/WEB-INF"
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_helper
    @helper.merb_root.should == "./WEB-INF"
  end

  it "should default merb_root to /WEB-INF" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_helper
    @helper.merb_root.should == "./WEB-INF"
  end

  it "should determine merb_env from the 'merb.env' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("merb.env").and_return "test"
    create_helper
    @helper.merb_env.should == "test"
  end

  it "should default merb_env to 'production'" do
    create_helper
    @helper.merb_env.should == "production"
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

  it "should create a Logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end
  
  it "should determine path_prefix from the 'path.prefix' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("path.prefix").and_return "/blah"
    create_helper
    @helper.path_prefix.should == "/blah"
  end
    
  it "should determine the session store from the 'session.store' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("session.store").and_return "blah"
    create_helper
    @helper.session_store.should == "blah"
  end
  
end
