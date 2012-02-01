#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack'

describe JRuby::Rack::Capture do
  before :each do
    $servlet_context = @servlet_context
    $servlet_context.stub!(:init_parameter_names).and_return []
  end

  it "should capture environment information" do
    @servlet_context.should_receive(:log)
    StandardError.new.tap do |e|
      e.capture
      e.store
    end
  end
end
