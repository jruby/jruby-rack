require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

java_import org.jruby.rack.RackContext
java_import org.jruby.rack.servlet.ServletRackContext
java_import org.jruby.rack.RackApplication
java_import org.jruby.rack.DefaultRackApplication
java_import org.jruby.rack.RackApplicationFactory
java_import org.jruby.rack.DefaultRackApplicationFactory
java_import org.jruby.rack.SharedRackApplicationFactory
java_import org.jruby.rack.PoolingRackApplicationFactory
java_import org.jruby.rack.rails.RailsRackApplicationFactory

describe "integration" do

  before(:all) { require 'fileutils' }

  describe 'rack (lambda)' do

    before do
      @servlet_context = org.jruby.rack.mock.RackLoggingMockServletContext.new "file://#{STUB_DIR}/rack"
      @servlet_context.logger = raise_logger
    end

    it "initializes" do
      @servlet_context.addInitParameter('rackup',
                                        "run lambda { |env| [ 200, {'Content-Type' => 'text/plain'}, 'OK' ] }"
      )

      listener = org.jruby.rack.RackServletContextListener.new
      listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)

      rack_factory = @servlet_context.getAttribute("rack.factory")
      expect(rack_factory).to be_a(RackApplicationFactory)
      expect(rack_factory).to be_a(SharedRackApplicationFactory)
      expect(rack_factory.realFactory).to be_a(DefaultRackApplicationFactory)

      expect(@servlet_context.getAttribute("rack.context")).to be_a(RackContext)
      expect(@servlet_context.getAttribute("rack.context")).to be_a(ServletRackContext)
    end

    context "initialized" do

      before :each do
        @servlet_context.addInitParameter('rackup',
                                          "run lambda { |env| [ 200, {'Via' => 'JRuby-Rack', 'Content-Type' => 'text/plain'}, 'OK' ] }"
        )
        listener = org.jruby.rack.RackServletContextListener.new
        listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)
        @rack_context = @servlet_context.getAttribute("rack.context")
        @rack_factory = @servlet_context.getAttribute("rack.factory")
      end

      it "inits servlet" do
        servlet_config = org.springframework.mock.web.MockServletConfig.new @servlet_context

        servlet = org.jruby.rack.RackServlet.new
        servlet.init(servlet_config)
        expect(servlet.getContext).to_not be nil
        expect(servlet.getDispatcher).to_not be nil
      end

      it "serves (servlet)" do
        dispatcher = org.jruby.rack.DefaultRackDispatcher.new(@rack_context)
        servlet = org.jruby.rack.RackServlet.new(dispatcher, @rack_context)

        request = org.springframework.mock.web.MockHttpServletRequest.new(@servlet_context)
        request.setMethod("GET")
        request.setRequestURI("/")
        request.setContentType("text/html")
        request.setContent("".to_java.bytes)
        response = org.springframework.mock.web.MockHttpServletResponse.new

        servlet.service(request, response)

        expect(response.getStatus).to eql 200
        expect(response.getContentType).to eql 'text/plain'
        expect(response.getContentAsString).to eql 'OK'
        expect(response.getHeader("Via")).to eql 'JRuby-Rack'
      end

    end

  end

  it "should have defined Rails stub tests" do
    expect(File.foreach(__FILE__).select { |line| line.include?("describe") }).to include(/^  describe.*lib: :#{CURRENT_LIB}/),
      "Expected rails stub tests to be defined for #{CURRENT_LIB} inside integration_spec.rb"
    expect(File.exist?(File.join(STUB_DIR, CURRENT_LIB.to_s))).to be(true),
      "Expected rails stub dir for #{CURRENT_LIB.to_s} to exist at #{File.join(STUB_DIR, CURRENT_LIB.to_s).inspect}"
  end if CURRENT_LIB.to_s.include?('rails')

  shared_examples_for 'a rails app', :shared => true do

    base_path = "file://#{STUB_DIR}/#{CURRENT_LIB.to_s}"

    let(:servlet_context) do
      new_servlet_context(base_path).tap { |servlet_context| prepare_servlet_context(servlet_context, base_path) }
    end

    context "runtime" do

      it "initializes (pooling by default)" do
        listener = org.jruby.rack.rails.RailsServletContextListener.new
        listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)

        rack_factory = servlet_context.getAttribute("rack.factory")
        expect(rack_factory).to be_a(RackApplicationFactory)
        expect(rack_factory).to be_a(PoolingRackApplicationFactory)
        expect(rack_factory).to respond_to(:realFactory)
        expect(rack_factory.realFactory).to be_a(RailsRackApplicationFactory)

        expect(servlet_context.getAttribute("rack.context")).to be_a(RackContext)
        expect(servlet_context.getAttribute("rack.context")).to be_a(ServletRackContext)

        expect(rack_factory.getApplication).to be_a(DefaultRackApplication)
      end

      it "initializes threadsafe!" do
        servlet_context.addInitParameter('jruby.max.runtimes', '1')

        listener = org.jruby.rack.rails.RailsServletContextListener.new
        listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)

        rack_factory = servlet_context.getAttribute("rack.factory")
        expect(rack_factory).to be_a(RackApplicationFactory)
        expect(rack_factory).to be_a(SharedRackApplicationFactory)
        expect(rack_factory.realFactory).to be_a(RailsRackApplicationFactory)

        expect(rack_factory.getApplication).to be_a(DefaultRackApplication)
      end
    end

    context "initialized" do

      before(:all) { copy_gemfile }

      before(:all) do
        initialize_rails('production', "file://#{base_path}") do |servlet_context, _|
          prepare_servlet_context(servlet_context, base_path)
        end
      end
      after(:all) { restore_rails }

      it "loaded rack ~> 2.2.0" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '2.2'
      end

      it "booted with a servlet logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_not_nil "Rails.logger"

        # production.rb: config.log_level = 'info'
        should_eval_as_eql_to "Rails.logger.level", Logger::INFO

        # Rails 7.1+ wraps the default in a ActiveSupport::BroadcastLogger
        if Rails::VERSION::STRING < '7.1'
          should_eval_as_eql_to "Rails.logger.is_a? JRuby::Rack::Logger", true
          should_eval_as_eql_to "Rails.logger.is_a? ActiveSupport::TaggedLogging", true
          unwrap_logger = "logger = Rails.logger;"
        else
          should_eval_as_not_nil "defined?(ActiveSupport::BroadcastLogger)"
          should_eval_as_eql_to "Rails.logger.is_a? ActiveSupport::BroadcastLogger", true
          should_eval_as_eql_to "Rails.logger.broadcasts.size", 1
          should_eval_as_eql_to "Rails.logger.broadcasts.first.is_a? JRuby::Rack::Logger", true
          # NOTE: TaggedLogging is a module that extends the logger instance:
          should_eval_as_eql_to "Rails.logger.broadcasts.first.is_a? ActiveSupport::TaggedLogging", true

          should_eval_as_eql_to "Rails.logger.broadcasts.first.level", Logger::INFO

          unwrap_logger = "logger = Rails.logger.broadcasts.first;"
        end

        # sanity check logger-silence works:
        should_eval_as_eql_to "#{unwrap_logger} logger.silence { logger.warn('from-integration-spec') }", true

        should_eval_as_eql_to "#{unwrap_logger} logger.real_logger.is_a?(Java::OrgJrubyRackServlet::DefaultServletRackContext)", true
      end

      it "sets up public_path" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_eql_to "Rails.public_path.to_s", "#{base_path}/public"
      end

      it "disables rack's chunked support (by default)" do
        @runtime = @rack_factory.getApplication.getRuntime
        expect_to_have_monkey_patched_chunked
      end
    end
  end

  describe 'rails 5.0', lib: :rails50 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 5.2', lib: :rails52 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 6.0', lib: :rails60 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 6.1', lib: :rails61 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 7.0', lib: :rails70 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 7.1', lib: :rails71 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 7.2', lib: :rails72 do
    it_should_behave_like 'a rails app'
  end

  describe 'rails 8.0', lib: :rails80 do
    it_should_behave_like 'a rails app'
  end

  def expect_to_have_monkey_patched_chunked
    @runtime.evalScriptlet "require 'rack/chunked'"
    script = %{
      headers = { 'Transfer-Encoding' => 'chunked' }

      body = Rack::Chunked::Body.new [ \"1\".freeze, \"\", \"\nsecond\" ]

      parts = []; body.each { |part| parts << part }
      parts.join
    }
    should_eval_as_eql_to script, "1\nsecond"
  end

  def initialize_rails(env = nil, servlet_context = @servlet_context)
    if !servlet_context || servlet_context.is_a?(String)
      base = servlet_context.is_a?(String) ? servlet_context : nil
      servlet_context = new_servlet_context(base)
    end
    listener = org.jruby.rack.rails.RailsServletContextListener.new

    the_env = "GEM_HOME=#{ENV['GEM_HOME']},GEM_PATH=#{ENV['GEM_PATH']}"
    the_env << "\nRAILS_ENV=#{env}" if env
    servlet_context.addInitParameter("jruby.runtime.env", the_env)

    yield(servlet_context, listener) if block_given?

    listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)
    @rack_context = servlet_context.getAttribute("rack.context")
    @rack_factory = servlet_context.getAttribute("rack.factory")
    @servlet_context = servlet_context
  end

  def new_servlet_context(base_path = nil)
    servlet_context = org.jruby.rack.mock.RackLoggingMockServletContext.new base_path
    servlet_context.logger = raise_logger('WARN').tap { |logger| logger.setEnabled(false) }
    servlet_context
  end

  def prepare_servlet_context(servlet_context, base_path)
    servlet_context.addInitParameter('rails.root', base_path)
    servlet_context.addInitParameter('jruby.rack.layout_class', 'FileSystemLayout')
  end

  GEMFILES_DIR = File.expand_path('../../../gemfiles', STUB_DIR)

  def copy_gemfile
    name = CURRENT_LIB.to_s
    raise "Environment variable BUNDLE_GEMFILE seems to not contain #{name}" unless ENV['BUNDLE_GEMFILE']&.include?(name)
    FileUtils.cp ENV['BUNDLE_GEMFILE'], File.join(STUB_DIR, "#{name}/Gemfile")
    FileUtils.cp "#{ENV['BUNDLE_GEMFILE']}.lock", File.join(STUB_DIR, "#{name}/Gemfile.lock")
    Dir.chdir File.join(STUB_DIR, name)
  end

  ENV_COPY = ENV.to_h

  def restore_rails
    ENV['RACK_ENV'] = ENV_COPY['RACK_ENV'] if ENV.key?('RACK_ENV')
    ENV['RAILS_ENV'] = ENV_COPY['RAILS_ENV'] if ENV.key?('RAILS_ENV')
  end

end
