target = File.expand_path('target', "#{File.dirname(__FILE__)}/../../..")
jars = File.exist?(lib = "#{target}/lib") && ( Dir.entries(lib) - [ '.', '..' ] )
raise "missing .jar dependencies please run `rake test_prepare'" if ! jars || jars.empty?
$CLASSPATH << File.expand_path('classes', target)
$CLASSPATH << File.expand_path('test-classes', target)
jars.each { |jar| $CLASSPATH << File.expand_path(jar, lib) }

java_import 'jakarta.servlet.http.HttpServletRequest'
java_import 'jakarta.servlet.http.HttpServletResponse'

java_import 'org.jruby.rack.RackApplicationFactory'
java_import 'org.jruby.rack.DefaultRackApplicationFactory'
java_import 'org.jruby.rack.servlet.RequestCapture'
java_import 'org.jruby.rack.servlet.ResponseCapture'
java_import 'org.jruby.rack.servlet.RewindableInputStream'

require 'rspec'

require 'jruby' # we rely on JRuby.runtime in a few places
JRuby::Util.load_ext('org.jruby.rack.ext.RackLibrary')

module SharedHelpers

  java_import 'org.jruby.rack.RackContext'
  java_import 'org.jruby.rack.RackConfig'
  java_import 'org.jruby.rack.servlet.ServletRackContext'
  java_import 'jakarta.servlet.ServletContext'
  java_import 'jakarta.servlet.ServletConfig'

  def mock_servlet_context
    @servlet_context = ServletContext.impl {}
    @rack_config ||= RackConfig.impl {}
    @rack_context ||= ServletRackContext.impl {}
    [ @rack_context, @servlet_context ].each do |context|
      context.stub(:log)
      context.stub(:isEnabled).and_return nil
      context.stub(:getInitParameter).and_return nil
      context.stub(:getRealPath).and_return "/"
      context.stub(:getResource).and_return nil
      context.stub(:getContextPath).and_return "/"
    end
    @rack_context.stub(:getConfig).and_return @rack_config
    @servlet_config ||= ServletConfig.impl {}
    @servlet_config.stub(:getServletName).and_return "a Servlet"
    @servlet_config.stub(:getServletContext).and_return @servlet_context
    @servlet_context
  end

  def servlet_context; mock_servlet_context end

  def silence_warnings(&block)
    JRuby::Rack::Helpers.silence_warnings(&block)
  end

  @@servlet_30 = nil

  def servlet_30?
    return @@servlet_30 unless @@servlet_30.nil?
    @@servlet_30 = !! ( Java::jakarta.servlet.AsyncContext rescue nil )
  end
  private :servlet_30?

  def rack_release(at_least = nil)
    require 'rack'; release = Rack.release
    release = '1.6' if Gem.loaded_specs['rack'].version.to_s == '1.6.0'
    at_least.nil? ? release : release >= at_least
  end
  private :rack_release

  def raise_logger(level = 'WARN')
    org.jruby.rack.logging.RaiseLogger.new(level, JRuby.runtime.out)
  end

  def gem_install_unless_installed(name, version)
    found = nil
    begin
      if Gem::Specification.respond_to? :find_all
        all = Gem::Specification.find_all
        found = all.find do |spec|
          spec.name == name && spec.version.to_s == version
        end
      elsif Gem::Specification.respond_to? :find_by_name
        found = Gem::Specification.find_by_name name, version
      else
        raise Gem::LoadError unless Gem.available? name, version
      end
    rescue Gem::LoadError
      found = false
    end
    # NOTE: won't ever be found in RubyGems >= 2.3 likely due Bundler
    unless found
      require 'rubygems/dependency_installer'
      installer = Gem::DependencyInstaller.new
      installer.install name, version
    end
  end

  ExpectationNotMetError = RSpec::Expectations::ExpectationNotMetError

  def expect_eql_java_bytes(actual, expected)
    if expected.length != actual.length
      raise ExpectationNotMetError, "byte[] arrays length differs"
    end
    i = 0; loop do
      if expected[i] != actual[i]
        raise ExpectationNotMetError, "byte[] arrays differ at #{i}"
      end
      break if ( i += 1 ) >= expected.length
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
    be_flag = options.has_key?(:should) ? options[:should] : be_truthy

    expected = expected.inspect.to_java
    actual = runtime.evalScriptlet(code).inspect.to_java
    actual.equals(expected).should be_flag, message.gsub('$expected', expected.to_s).gsub('$actual', actual.to_s)
  end

  def should_eval_as_not_eql_to(code, expected, options = {})
    should_eval_as_eql_to(code, expected, options.merge(:should => be_falsy,
        :message => options[:message] || "expected eval #{code.inspect} to be != $expected but was not")
    )
  end

  def should_eval_as_nil(code, runtime = @runtime)
    should_eval_as_eql_to code, nil, :runtime => runtime,
      :message => "expected eval #{code.inspect} to be nil but was $actual"
  end

  def should_eval_as_not_nil(code, runtime = @runtime)
    should_eval_as_eql_to code, nil, :should => be_falsy, :runtime => runtime,
      :message => "expected eval #{code.inspect} to not be nil but was"
  end

  def should_not_eval_as_nil(code, runtime = @runtime) # alias
    should_eval_as_not_nil(code, runtime)
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
    require 'logger' # Workaround for concurrent-ruby problems on older rails versions
    require 'rails/version' # use Rails::VERSION to detect current env
    require 'rails' # attempt to load rails - for "real life" testing
  end
rescue LoadError
end

# current 'library' environment (based on appraisals) e.g. :rails72
CURRENT_LIB = defined?(Rails::VERSION) ? :"rails#{Rails::VERSION::MAJOR}#{Rails::VERSION::MINOR}" : :stub

puts "using JRuby #{JRUBY_VERSION} (#{RUBY_VERSION}) CURRENT_LIB: #{CURRENT_LIB.inspect}"

RSpec.configure do |config|

  config.include SharedHelpers

  config.before(:each) do
    @env_save = ENV.to_hash
    mock_servlet_context
  end

  config.after(:each) do
    (ENV.keys - @env_save.keys).each {|k| ENV.delete k}
    @env_save.each {|k,v| ENV[k] = v}
    Dir.chdir(WD_START) unless Dir.getwd == WD_START
    $servlet_context = nil if defined? $servlet_context
  end

  # NOTE: only works when no other example filtering is in place: e.g. `rspec ... --example=logger` won't filter here
  config.filter_run_excluding lib: lambda { |lib| lib.nil? ? false : !Array(lib).include?(CURRENT_LIB) }

  config.backtrace_exclusion_patterns = [
    /bin\//,
    #/gems/,
    /spec\/spec_helper\.rb/,
  ]

end

java_import 'org.springframework.mock.web.MockServletConfig'
java_import 'org.springframework.mock.web.MockServletContext'
java_import 'org.springframework.mock.web.MockHttpServletRequest'
java_import 'org.springframework.mock.web.MockHttpServletResponse'

class StubInputStream < java.io.InputStream

  def initialize(val = "")
    super()
    @stream = java.io.ByteArrayInputStream.new(val.to_s.to_java_bytes)
  end

  def read
    @stream.read
  end

end

class StubOutputStream < java.io.OutputStream

  def initialize
    super()
    @stream = java.io.ByteArrayOutputStream.new
  end

  def write(b)
    @stream.write(b)
  end

  def to_s
    String.from_java_bytes to_java_bytes
  end

  def to_java_bytes
    @stream.to_byte_array
  end

  def flush; end

end

class StubServletInputStream < Java::JakartaServlet::ServletInputStream

  def initialize(val = "")
    @delegate = StubInputStream.new(val)
  end

  def method_missing(meth, *args)
    @delegate.send(meth, *args)
  end

end
