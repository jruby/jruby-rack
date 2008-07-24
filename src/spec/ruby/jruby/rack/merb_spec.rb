require File.dirname(__FILE__) + '/../../spec_helper'

require 'jruby/rack/merb'
import org.jruby.rack.merb.MerbRackApplicationFactory

describe JRuby::Rack::MerbServletHelper do
  before :each do
    @servlet_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = JRuby::Rack::MerbServletHelper.new @servlet_context
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

  it "should determine merb_environment from the 'merb.environment' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("merb.environment").and_return "test"
    create_helper
    @helper.merb_environment.should == "test"
  end

  it "should default merb_environment to 'production'" do
    create_helper
    @helper.merb_environment.should == "production"
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should default public root to '/WEB-INF/public'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_helper
    @helper.public_root.should == "./public"
  end

  it "should create a Logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end

end

describe MerbRackApplicationFactory, "getApplication" do
  before :each do
    @app_factory = MerbRackApplicationFactory.new
    @servlet_context.stub!(:getRealPath).and_return Dir.pwd
    @app_factory.init(@servlet_context)
    @merb_root = File.dirname(__FILE__) + '/../../merb'
  end
   
  it "should load the Merb environment and return an application" do
    @servlet_context.should_receive(:getInitParameter).
      with(/public|files|gem|merb\.env/).any_number_of_times.and_return nil
    @servlet_context.should_receive(:getInitParameter).
      with("merb.root").and_return("merb/root")
    @servlet_context.should_receive(:getRealPath).
      with("merb/root").and_return(@merb_root)
    app = @app_factory.getApplication
    app.should respond_to(:call)
  end  
end
