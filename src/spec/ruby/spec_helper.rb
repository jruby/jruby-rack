#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'
require 'rubygems'
gem 'rspec'
require 'spec'
# add to load path for stubbed out action_controller
$LOAD_PATH << File.dirname(__FILE__) + '/rails'

Spec::Runner.configure do |config|
  def mock_servlet_context
    @rack_context = mock "rack context"
    @servlet_context = mock "servlet context"
    [@rack_context, @servlet_context].each do |context|
      context.stub!(:log)
      context.stub!(:getInitParameter).and_return nil
    end
    @servlet_config = mock("servlet config")
    @servlet_config.stub!(:getServletName).and_return("A Servlet")
    @servlet_config.stub!(:getServletContext).and_return(@servlet_context)
  end

  def create_booter(booter_class = JRuby::Rack::Booter)
    require 'jruby/rack'
    @booter = booter_class.new @rack_context
    yield if block_given?
    @booter
  end

  config.before :each do
    mock_servlet_context
  end
end

import org.jruby.rack.RackServletContextListener unless defined?(RackServletContextListener)
import org.jruby.rack.RackContext unless defined?(RackContext)

class StubInputStream < java.io.InputStream
  def initialize(val = "")
    super()
    @is = java.io.ByteArrayInputStream.new(val.to_s.to_java_bytes)
  end
  def read
    @is.read
  end
end
