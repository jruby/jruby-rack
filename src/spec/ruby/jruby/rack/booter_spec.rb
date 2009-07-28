#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/booter'

describe JRuby::Rack::Booter do
  before :each do
    @rack_context.stub!(:getInitParameter).and_return nil
    @rack_context.stub!(:getRealPath).and_return "/"
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_booter.boot!
    @booter.public_path.should == "."
  end

  it "should convert public.root to not have any trailing slashes" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah/"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "/blah/blah"
    create_booter.boot!
    @booter.public_path.should == "/blah/blah"
  end

  it "should default public root to '/'" do
    @rack_context.should_receive(:getRealPath).with("/").and_return "."
    create_booter.boot!
    @booter.public_path.should == "."
  end

  it "should determine the gem path from the gem.path init parameter" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_booter.boot!
    @booter.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_booter.boot!
    @booter.gem_path.should == "./gems"
  end

  it "should set Gem.path to the value of gem_path" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    create_booter.boot!
    ENV['GEM_PATH'].should == "/blah/gems"
  end

  it "should create a logger that writes messages to the servlet context" do
    create_booter.boot!
    @rack_context.should_receive(:log).with(/hello/)
    @booter.logger.info "hello"
  end
end

