#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')
require 'jruby/rack'

describe JRuby::Rack::Capture do
  
  before :each do
    JRuby::Rack.context = nil
    $servlet_context = @servlet_context
    @servlet_context.stub!(:init_parameter_names).and_return []
  end

  it "should capture environment information" do
    @servlet_context.should_receive(:log)
    error = StandardError.new
    error.capture
    error.store
  end
  
end
