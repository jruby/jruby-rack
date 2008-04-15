#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'
require 'rubygems'
gem 'rspec'
require 'spec'

Spec::Runner.configure do |config|
  def mock_servlet_context
    @servlet_context = mock("servlet context")
    @servlet_context.stub!(:log)
    @servlet_config = mock("servlet config")
    @servlet_config.stub!(:getServletName).and_return("A Servlet")
    @servlet_config.stub!(:getServletContext).and_return(@servlet_context)
  end

  config.before :each do
    mock_servlet_context
  end
end
