#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/servlet_helper'

describe JRuby::Rack::ServletHelper do
  before :each do
    @rack_context.stub!(:getInitParameter).and_return nil
    @rack_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = JRuby::Rack::ServletHelper.new @rack_context
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.public_path.should == "."
  end

  it "should convert public.root to not have any trailing slashes" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah/"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "/blah/blah"
    create_helper
    @helper.public_path.should == "/blah/blah"
  end

  it "should default public root to '/WEB-INF/public'" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_helper
    @helper.public_path.should == "./public"
  end

  it "should determine the gem path from the gem.path init parameter" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_helper
    @helper.gem_path.should == "./gems"
  end

  it "should set Gem.path to the value of gem_path" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    create_helper
    ENV['GEM_PATH'].should == "/blah/gems"
  end

  it "should create a logger that writes messages to the servlet context" do
    create_helper
    @rack_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end

  it "should allow a custom initializer script to be evaluated as the helper is initialized" do
    @rack_context.should_receive(:getInitParameter
      ).with("rack.bootstrap.script").and_return "load '#{File.dirname(__FILE__)}/custom_bootstrap.rb'"
    create_helper
    @helper.app_path.should == "/app"
    @helper.public_path.should == "/web"
  end
end

