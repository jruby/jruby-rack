#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack'

describe JRuby::Rack::LoadPathDebugging do
  before :each do
    $servlet_context = @servlet_context
    @klass = Class.new(LoadError) do
      include JRuby::Rack::LoadPathDebugging
    end
  end

  it "should dump a message to the servlet context log with the current load path" do
    @servlet_context.should_receive(:log).and_return do |msg|
      msg.should =~ /LoadError while loading 'rack'/
    end
    @klass.new "no such file to load -- rack"
  end
end
