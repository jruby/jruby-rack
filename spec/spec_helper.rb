#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'rubygems'
gem 'rspec'
require 'spec'

Spec::Runner.configure do |config|
  config.before :each do
    @servlet_context = mock("servlet context")
    @servlet_context.stub!(:log)
    @servlet_config = mock("servlet config")
    @servlet_config.stub!(:getServletName).and_return("A Servlet")
    @servlet_config.stub!(:getServletContext).and_return(@servlet_context)
  end
end
