#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'
require 'spec'

# add to load path for stubbed out action_controller, railtie classes
$LOAD_PATH.unshift File.expand_path('../rails', __FILE__)

WD_START = Dir.getwd

java_import org.jruby.rack.RackContext
java_import org.jruby.rack.RackServletContextListener
java_import javax.servlet.ServletContext

Spec::Runner.configure do |config|
  def mock_servlet_context
    @rack_context ||= RackContext.impl {}
    @servlet_context ||= ServletContext.impl {}
    [@rack_context, @servlet_context].each do |context|
      context.stub!(:log)
      context.stub!(:getInitParameter).and_return nil
      context.stub!(:getRealPath).and_return "/"
      context.stub!(:getResource).and_return nil
      context.stub!(:getContextPath).and_return "/"
    end
    @servlet_config ||= mock("servlet config")
    @servlet_config.stub!(:getServletName).and_return("A Servlet")
    @servlet_config.stub!(:getServletContext).and_return(@servlet_context)
  end

  def create_booter(booter_class = JRuby::Rack::Booter)
    require 'jruby/rack'
    @booter = booter_class.new @rack_context
    yield @booter if block_given?
    @booter
  end

  config.before :each do
    @env_save = ENV.to_hash
    mock_servlet_context
  end

  config.after :each do
    (ENV.keys - @env_save.keys).each {|k| ENV.delete k}
    @env_save.each {|k,v| ENV[k] = v}
    Dir.chdir(WD_START) unless Dir.getwd == WD_START
    $servlet_context = nil
  end
end


class StubInputStream < java.io.InputStream
  def initialize(val = "")
    super()
    @is = java.io.ByteArrayInputStream.new(val.to_s.to_java_bytes)
  end
  def read
    @is.read
  end
end
