#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack/booter'

describe JRuby::Rack::Booter do
  before :each do
    $loaded_init_rb = nil
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

  it "should chomp trailing slashes from paths" do
    @rack_context.should_receive(:getRealPath).with("/").and_return "/hello/there/"
    create_booter.boot!
    @booter.public_path.should == "/hello/there"
  end

  it "should determine the gem path from the gem.path init parameter" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_booter.boot!
    @booter.gem_path.should == "."
  end

  it "should also be able to determine the gem path from the gem.home init parameter" do
    @rack_context.should_receive(:getInitParameter).with("gem.home").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_booter.boot!
    @booter.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_booter.boot!
    @booter.gem_path.should == "./gems"
  end

  it "should get rack environment from rack.env" do
    @rack_context.should_receive(:getInitParameter).with("rack.env").and_return "production"
    create_booter.boot!
    ENV['RACK_ENV'].should == "production"
  end

  it "should prepend gem_path to ENV['GEM_PATH']  " do
    ENV['GEM_PATH'] = '/other/gems'
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    create_booter.boot!
    ENV['GEM_PATH'].should == "/blah/gems#{File::PATH_SEPARATOR}/other/gems"
  end

  it "should set ENV['GEM_PATH'] to the value of gem_path if ENV['GEM_PATH'] is not present" do
    ENV['GEM_PATH'] = nil
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    create_booter.boot!
    ENV['GEM_PATH'].should == "/blah/gems"
  end

  it "should create a logger that writes messages to the servlet context" do
    create_booter.boot!
    @rack_context.should_receive(:log).with(/hello/)
    @booter.logger.info "hello"
  end

  it "should load and execute ruby code in META-INF/init.rb if it exists" do
    @rack_context.should_receive(:getResource).with("/META-INF/init.rb").and_return java.net.URL.new("file:#{File.expand_path('../init.rb', __FILE__)}")
    create_booter.boot!
    $loaded_init_rb.should == true
  end

  it "should load and execute ruby code in WEB-INF/init.rb if it exists" do
    @rack_context.should_receive(:getResource).with("/WEB-INF/init.rb").and_return java.net.URL.new("file:#{File.expand_path('../init.rb', __FILE__)}")
    create_booter.boot!
    $loaded_init_rb.should == true
  end
end

