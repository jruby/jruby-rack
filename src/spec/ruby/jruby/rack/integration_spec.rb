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

  #after(:all) { JRuby::Rack.context = nil }

  describe 'rack (lambda)' do

    before do
      @servlet_context = org.jruby.rack.mock.RackLoggingMockServletContext.new "file://#{STUB_DIR}/rack"
      @servlet_context.logger = raise_logger
      # make sure we always boot runtimes in the same mode as specs :
      set_compat_version @servlet_context
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

  shared_examples_for 'a rails app', :shared => true do

    let(:servlet_context) { new_servlet_context(base_path) }

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

  ENV_COPY = ENV.to_h

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
    @servlet_context ||= servlet_context
  end

  def restore_rails
    #ENV['RACK_ENV'] = ENV_COPY['RACK_ENV'] if ENV.key?('RACK_ENV')
    #ENV['RAILS_ENV'] = ENV_COPY['RAILS_ENV'] if ENV.key?('RAILS_ENV')
  end

  def new_servlet_context(base_path = nil)
    servlet_context = org.jruby.rack.mock.RackLoggingMockServletContext.new base_path
    servlet_context.logger = raise_logger
    prepare_servlet_context servlet_context
    servlet_context
  end

  def prepare_servlet_context(servlet_context)
    set_compat_version servlet_context
  end

  def set_compat_version(servlet_context = @servlet_context); require 'jruby'
    compat_version = JRuby.runtime.getInstanceConfig.getCompatVersion # RUBY1_9
    servlet_context.addInitParameter("jruby.compat.version", compat_version.to_s)
  end

  private

  GEMFILES_DIR = File.expand_path('../../../gemfiles', STUB_DIR)

  def copy_gemfile(name)
    # e.g. 'rails30'
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile")
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile.lock"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile.lock")
  end

end
