#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/app_layout'

describe JRuby::Rack::WebInfLayout do

  let(:layout) { JRuby::Rack::WebInfLayout.new(@rack_context) }

  it "sets app uri defaults to WEB-INF" do
    expect( layout.app_uri ).to eq '/WEB-INF'
  end

  it "uses app.root param as app uri" do
    @rack_context.should_receive(:getInitParameter).with("app.root").and_return "/AppRoot"
    expect( layout.app_uri ).to eq '/AppRoot'
  end

  it "uses rails.root param as app uri" do
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return "Rails/Root"
    expect( layout.app_uri ).to eq 'Rails/Root'
  end

  it "defaults gem uri to /WEB-INF/gems" do
    expect( layout.gem_uri ).to eq '/WEB-INF/gems'

    @rack_context.should_receive(:getRealPath).with("/WEB-INF/gems").and_return "/gems"

    expect( layout.gem_path ).to eq '/gems'
  end

  it "sets gem path based on gem.path context init param" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "/WEB-INF/.gems"
    expect( layout.gem_uri ).to eq "/WEB-INF/.gems"

    @rack_context.should_receive(:getRealPath).with("/WEB-INF/.gems").and_return "file:/tmp/WEB-INF/.gems"

    expect( layout.gem_path ).to eq "file:/tmp/WEB-INF/.gems"
  end

  it "handles gem path correctly when app uri ends with /" do
    layout.instance_variable_set :@app_uri, "/WEB-INF/"
    layout.instance_variable_set :@gem_uri, "/WEB-INF/.gems"

    @rack_context.should_receive(:getRealPath).with("/WEB-INF/.gems").and_return ".gems"

    expect( layout.gem_path ).to eq ".gems"
  end

  it "handles gem path correctly when app uri not relative" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF/.gems").and_return "/var/local/app/WEB-INF/.gems"
    layout.instance_variable_set :@gem_uri, "/WEB-INF/.gems"
    layout.instance_variable_set :@app_uri, "/WEB-INF/app"
    expect( layout.gem_path ).to eq "/var/local/app/WEB-INF/.gems"
  end

  it "chomps non-relative gem path for ending /" do
    @rack_context.should_receive(:getRealPath).with("/gem/").and_return "/var/local/app/gem/"
    layout.instance_variable_set :@gem_uri, "/gem/"
    expect( layout.gem_path ).to eq "/var/local/app/gem"
  end

  it "expands path app_uri relatively" do
    layout.instance_variable_set :@app_uri, "/WEB-INF/"
    layout.instance_variable_set :@app_path, "/home/deploy/current/WEB-INF/"

    expect( layout.expand_path("app/gem") ).to eq "/home/deploy/current/WEB-INF/app/gem"
  end

  it "expands paths starting with app path" do
    layout.instance_variable_set :@app_uri, "/WEB-INF"
    layout.instance_variable_set :@app_path, "/home/deploy/current/WEB-INF"

    expect( layout.expand_path("/WEB-INF/app/gem") ).to eq "/home/deploy/current/WEB-INF/app/gem"
  end

  it "expands nil path as nil" do
    layout.instance_variable_set :@app_uri, "/WEB-INF/"

    expect( layout.expand_path(nil) ).to eq nil
  end

end

shared_examples "FileSystemLayout" do

  it "sets app and public uri defaults based on a typical (Rails/Rack) app" do
    expect( layout.app_uri ).to eq '.'
    expect( layout.public_uri ).to eq 'public'

    expect( layout.app_path ).to eq Dir.pwd
    expect( layout.public_path ).to eq "#{Dir.pwd}/public"
  end

  it "sets public uri using context param" do
    @rack_context.should_receive(:getRealPath).with("static").and_return File.expand_path("static")
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "static"
    expect( layout.public_uri ).to eq 'static'
    expect( layout.public_path ).to eq "#{Dir.pwd}/static"
  end

  it "sets gem path based on gem.path context init param" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "gem/path/"
    expect( layout.gem_uri ).to eq "gem/path/"
    expect( layout.gem_path ).to eq File.expand_path("gem/path")
  end

  it "sets gem path based on gem.home context init param" do
    @rack_context.should_receive(:getRealPath).with("gem/home").and_return File.expand_path("gem/home")
    @rack_context.should_receive(:getInitParameter).with("gem.home").and_return "gem/home"
    expect( layout.gem_uri ).to eq "gem/home"
    expect( layout.gem_path ).to eq File.expand_path("gem/home")
  end

  it "gem_path returns nil (assumes to be set from ENV) when not set" do
    @rack_context.should_receive(:getInitParameter).with("gem.home").and_return nil
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return nil
    expect( layout.gem_uri ).to be nil
    expect( layout.gem_path ).to be nil
  end

  it "expands public path relative to application root" do
    layout.instance_variable_set :@app_uri, '/opt/deploys/main'
    expect( layout.public_path ).to eq "/opt/deploys/main/public"
  end

  it "expands public path relative to application root (unless absolute)" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/home/public/root"
    expect( layout.public_path ).to eq "/home/public/root"
  end

  it "expands nil path as nil" do
    expect( layout.expand_path(nil) ).to eq nil
  end

  it "handles nil real path as nil" do
    expect( layout.real_path(nil) ).to eq nil
  end

end

describe JRuby::Rack::FileSystemLayout do

  let(:layout) do
    @rack_context.stub(:getRealPath) { |path| path }
    JRuby::Rack::FileSystemLayout.new(@rack_context)
  end

  it_behaves_like "FileSystemLayout"

  it "sets app uri from an app.root context param" do
    @rack_context.should_receive(:getInitParameter).with("app.root").and_return "/home/app/current"
    expect( layout.app_uri ).to eq '/home/app/current'
    expect( layout.app_path ).to eq '/home/app/current'
  end

  describe "deprecated-constant" do

    it "still works" do
      expect(JRuby::Rack::RailsFilesystemLayout).to be JRuby::Rack::FileSystemLayout
    end

  end

end

describe JRuby::Rack::RailsFileSystemLayout do

  let(:layout) do
    @rack_context.stub(:getRealPath) { |path| path }
    JRuby::Rack::RailsFileSystemLayout.new(@rack_context)
  end

  it_behaves_like "FileSystemLayout"

  it "sets app uri from a rails.root context param" do
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return "../rails"
    expect( layout.app_uri ).to eq '../rails'
    expect( layout.app_path ).to eq File.expand_path("../rails", Dir.pwd)
  end

end if defined? JRuby::Rack::RailsFileSystemLayout
