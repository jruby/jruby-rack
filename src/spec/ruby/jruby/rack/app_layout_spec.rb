#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack/app_layout'

describe JRuby::Rack::RailsFilesystemLayout do
  def layout
    @layout ||= JRuby::Rack::RailsFilesystemLayout.new(@rack_context)
  end

  it "should set app and public uri defaults based on a typical Rails app" do
    layout.public_uri.should == './public'
    layout.app_uri.should == '.'
  end

  it "should set gem path based on gem.path or gem.home context init params" do
    @rack_context.should_receive(:getInitParameter).with("gem.path").and_return "gem/path"
    layout.gem_uri.should == "gem/path"
    @layout = nil
    @rack_context.should_receive(:getInitParameter).with("gem.home").and_return "gem/home"
    layout.gem_uri.should == "gem/home"
  end
end
