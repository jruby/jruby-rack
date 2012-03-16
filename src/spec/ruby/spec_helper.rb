#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rspec'

require 'java'
begin
  require File.expand_path('target/classpath.rb', File.dirname(__FILE__) + '/../../..')
rescue LoadError => e
  puts "classpath.rb script missing try running `rake clean compile` first"
  raise e
end unless defined?(Maven.set_classpath)
Maven.set_classpath

java_import 'org.jruby.rack.RackContext'
java_import 'org.jruby.rack.RackConfig'
java_import 'org.jruby.rack.RackServletContextListener'
java_import 'org.jruby.rack.servlet.ServletRackContext'
java_import 'javax.servlet.ServletContext'
java_import 'javax.servlet.ServletConfig'

module SharedHelpers
  
  def mock_servlet_context
    @rack_config ||= RackConfig.impl {}
    @rack_context ||= ServletRackContext.impl {}
    @servlet_context ||= ServletContext.impl {}
    [@rack_context, @servlet_context].each do |context|
      context.stub!(:log)
      context.stub!(:getInitParameter).and_return nil
      context.stub!(:getRealPath).and_return "/"
      context.stub!(:getResource).and_return nil
      context.stub!(:getContextPath).and_return "/"
    end
    @rack_context.stub!(:getConfig).and_return @rack_config
    @servlet_config ||= ServletConfig.impl {}
    @servlet_config.stub!(:getServletName).and_return "A Servlet"
    @servlet_config.stub!(:getServletContext).and_return @servlet_context
  end

  def create_booter(booter_class = JRuby::Rack::Booter)
    @booter = booter_class.new @rack_context
    yield @booter if block_given?
    @booter
  end

  @@raise_logger = nil
  
  def raise_logger
    @@raise_logger ||= org.jruby.rack.RackLogger.impl do |name, *args|
      raise args[1] if name.to_s == 'log' && args[1] != nil # log(str, error)
    end
  end
  
  # org.jruby.Ruby.evalScriptlet helpers - comparing values from different runtimes

  def should_eval_as_eql_to(code, expected, options = {})
    if options.is_a?(Hash)
      runtime = options[:runtime] || @runtime
    else
      runtime, options = options, {}
    end
    message = options[:message] || "expected eval #{code.inspect} to be == $expected but was $actual"
    be_flag = options.has_key?(:should) ? options[:should] : be_true
    
    expected = expected.inspect.to_java
    actual = runtime.evalScriptlet(code).inspect.to_java
    actual.equals(expected).should be_flag, message.gsub('$expected', expected.to_s).gsub('$actual', actual.to_s)
  end
  
  def should_eval_as_not_eql_to(code, expected, options = {})
    should_eval_as_eql_to(code, expected, options.merge(:should => be_false, 
        :message => options[:message] || "expected eval #{code.inspect} to be != $expected but was not")
    )
  end
  
  def should_eval_as_nil(code, runtime = @runtime)
    should_eval_as_eql_to code, nil, :runtime => runtime, 
      :message => "expected eval #{code.inspect} to be nil but was $actual"
  end

  def should_eval_as_not_nil(code, runtime = @runtime)
    should_eval_as_eql_to code, nil, :should => be_false, :runtime => runtime, 
      :message => "expected eval #{code.inspect} to not be nil but was"
  end
  
  def should_not_eval_as_nil(code, runtime = @runtime) # alias
    should_eval_as_not_nil(code, runtime)
  end
  
end

STUB_DIR = File.expand_path('../stub', File.dirname(__FILE__))

WD_START = Dir.getwd

begin
  # NOTE: only if running with a `bundle exec` to better isolate
  if $LOAD_PATH.find { |path| path =~ /\/rails\-[\d\.]*\// }
    require 'rails' # attempt to load rails - for "real life" testing
    require 'rails/version' # use Rails::VERSION to detect current env
  end
rescue LoadError
end
# add to load path for stubbed out action_controller, railtie etc
$LOAD_PATH.unshift File.expand_path('../rails/stub', __FILE__) unless defined?(Rails::VERSION)

# current 'library' environment (based on appraisals) e.g. :rails31
CURRENT_LIB = defined?(Rails::VERSION) ? 
  :"rails#{Rails::VERSION::MAJOR}#{Rails::VERSION::MINOR}" : :stub

RSpec.configure do |config|

  config.include SharedHelpers
  
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
  
  config.filter_run_excluding :lib => lambda { |lib|
    return false if lib.nil? # no :lib => specified run with all
    ! ( lib.is_a?(Array) ? lib : [ lib ] ).include?(CURRENT_LIB)
  }
  
  config.backtrace_clean_patterns = [
    /bin\//,
    /gems/,
    /spec\/spec_helper\.rb/,
    /lib\/rspec\/(core|expectations|matchers|mocks)/
  ]
  
end

import org.jruby.rack.mock.MockServletConfig
import org.jruby.rack.mock.MockServletContext
import org.jruby.rack.mock.MockHttpServletRequest
import org.jruby.rack.mock.MockHttpServletResponse

class StubInputStream < java.io.InputStream
  def initialize(val = "")
    super()
    @is = java.io.ByteArrayInputStream.new(val.to_s.to_java_bytes)
  end
  def read
    @is.read
  end
end

class StubOutputStream < java.io.OutputStream
  def initialize
    super()
    @os = java.io.ByteArrayOutputStream.new
  end

  def write(b)
    @os.write(b)
  end

  def to_s
    String.from_java_bytes @os.to_byte_array
  end
end

class StubServletInputStream < javax.servlet.ServletInputStream
  def initialize(val = "")
    @delegate = StubInputStream.new(val)
  end

  def method_missing(meth, *args)
    @delegate.send(meth, *args)
  end
end
