#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rspec'

require 'java'
target = File.expand_path('target', "#{File.dirname(__FILE__)}/../../..")
jars = File.exist?(lib = "#{target}/lib") && ( Dir.entries(lib) - [ '.', '..' ] )
raise "missing .jar dependencies please run `rake test_jars'" if ! jars || jars.empty?
$CLASSPATH << File.expand_path('classes', target)
$CLASSPATH << File.expand_path('test-classes', target)
jars.each { |jar| $CLASSPATH << File.expand_path(jar, lib) }

# Java imports :
java_import 'javax.servlet.ServletContext'
java_import 'javax.servlet.ServletConfig'
java_import 'javax.servlet.http.HttpServletRequest'
java_import 'javax.servlet.http.HttpServletResponse'

java_import 'org.jruby.rack.mock.MockServletConfig'
java_import 'org.jruby.rack.mock.MockServletContext'
java_import 'org.jruby.rack.mock.MockHttpServletRequest'
java_import 'org.jruby.rack.mock.MockHttpServletResponse'

java_import 'org.jruby.rack.RackContext'
java_import 'org.jruby.rack.RackConfig'
java_import 'org.jruby.rack.RackApplicationFactory'
java_import 'org.jruby.rack.DefaultRackApplicationFactory'
java_import 'org.jruby.rack.RackServletContextListener'
java_import 'org.jruby.rack.servlet.ServletRackContext'
java_import 'org.jruby.rack.servlet.RequestCapture'
java_import 'org.jruby.rack.servlet.ResponseCapture'
java_import 'org.jruby.rack.servlet.RewindableInputStream'

module SharedHelpers

  def mock_servlet_context
    @servlet_context = ServletContext.impl {}
    @rack_config ||= RackConfig.impl {}
    @rack_context ||= ServletRackContext.impl {}
    [@rack_context, @servlet_context].each do |context|
      context.stub(:log)
      context.stub(:getInitParameter).and_return nil
      context.stub(:getRealPath).and_return "/"
      context.stub(:getResource).and_return nil
      context.stub(:getContextPath).and_return "/"
    end
    @rack_context.stub(:getConfig).and_return @rack_config
    @servlet_config ||= ServletConfig.impl {}
    @servlet_config.stub(:getServletName).and_return "A Servlet"
    @servlet_config.stub(:getServletContext).and_return @servlet_context
    @servlet_context
  end

  def servlet_context; mock_servlet_context end

  def silence_warnings(&block)
    JRuby::Rack::Helpers.silence_warnings(&block)
  end

  def unwrap_native_exception(e)
    # JRuby 1.6.8 issue :
    #  begin
    #    ...
    #  rescue org.jruby.rack.RackInitializationException => e
    #    # e is still wrapped in a NativeException !
    #    e.cause.class.name == 'org.jruby.rack.RackInitializationException'
    #  end
    if JRUBY_VERSION < '1.7.0'
      e.is_a?(NativeException) ? e.cause : e
    else
      e
    end
  end

  def set_rack_input(servlet_env); require 'jruby'
    input_class = org.jruby.rack.RackInput.getRackInputClass(JRuby.runtime)
    input = input_class.new(servlet_env.getInputStream)
    servlet_env.set_io input # servlet_env.instance_variable_set :@_io, input
    input
  end

  @@servlet_30 = nil

  def servlet_30?
    return @@servlet_30 unless @@servlet_30.nil?
    @@servlet_30 = !! ( Java::JavaClass.for_name('javax.servlet.AsyncContext') rescue nil )
  end
  private :servlet_30?

  @@raise_logger = nil

  def raise_logger
    @@raise_logger ||= org.jruby.rack.RackLogger.impl do |name, *args|
      if name.to_s == 'log' && args[0] =~ /^(ERROR|WARN):/
        puts args[0]
        if error = args[1] # org.jruby.exceptions.RaiseException
          error.printStackTrace if error.is_a?(java.lang.Throwable)
        end
        raise args[0]
      end
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

# "stub" streams :

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

# NOTE: avoid chunked-patch (loaded by default from a hook at
# DefaultRackApplicationFactory.initRuntime) to be loaded in (spec) runtime :
$LOADED_FEATURES << 'jruby/rack/chunked.rb'

STUB_DIR = File.expand_path('../stub', File.dirname(__FILE__))

WD_START = Dir.getwd

begin
  # NOTE: only if running with a `bundle exec` to better isolate
  if $LOAD_PATH.find { |path| path =~ /\/rails\-[\w\.]*\// }
    require 'rails/version' # use Rails::VERSION to detect current env
    require 'rails' # attempt to load rails - for "real life" testing
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
    $servlet_context = nil if defined? $servlet_context
  end

  config.filter_run_excluding :lib => lambda { |lib|
    return false if lib.nil? # no :lib => specified run with all
    lib = lib.is_a?(Array) ? lib : [ lib ]
    if CURRENT_LIB == :rails40
      if RUBY_VERSION < '1.9'
        return true # NOTE: no sense running Rails 4.0 on 1.8.x
      end
      #return ! lib.include?(:rails32)
    end
    ! lib.include?(CURRENT_LIB)
  }

  config.backtrace_exclusion_patterns = [
    /bin\//,
    #/gems/,
    /spec\/spec_helper\.rb/,
    /lib\/rspec\/(core|expectations|matchers|mocks)/
  ]

end
