
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
      listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(@servlet_context)

      rack_factory = @servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(SharedRackApplicationFactory)
      rack_factory.realFactory.should be_a(DefaultRackApplicationFactory)

      @servlet_context.getAttribute("rack.context").should be_a(RackContext)
      @servlet_context.getAttribute("rack.context").should be_a(ServletRackContext)
    end

    context "initialized" do

      before :each do
        @servlet_context.addInitParameter('rackup',
            "run lambda { |env| [ 200, {'Via' => 'JRuby-Rack', 'Content-Type' => 'text/plain'}, 'OK' ] }"
        )
        listener = org.jruby.rack.RackServletContextListener.new
        listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(@servlet_context)
        @rack_context = @servlet_context.getAttribute("rack.context")
        @rack_factory = @servlet_context.getAttribute("rack.factory")
      end

      it "inits servlet" do
        servlet_config = org.springframework.mock.web.MockServletConfig.new @servlet_context

        servlet = org.jruby.rack.RackServlet.new
        servlet.init(servlet_config)
        expect( servlet.getContext ).to_not be nil
        expect( servlet.getDispatcher ).to_not be nil
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

        expect( response.getStatus ).to eql 200
        expect( response.getContentType ).to eql 'text/plain'
        expect( response.getContentAsString ).to eql 'OK'
        expect( response.getHeader("Via") ).to eql 'JRuby-Rack'
      end

    end

  end

  shared_examples_for 'a rails app', :shared => true do

    let(:servlet_context) { new_servlet_context(base_path) }

    it "initializes pooling when min/max set" do
      servlet_context.addInitParameter('jruby.min.runtimes', '1')
      servlet_context.addInitParameter('jruby.max.runtimes', '2')

      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(servlet_context)

      rack_factory = servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(PoolingRackApplicationFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      servlet_context.getAttribute("rack.context").should be_a(RackContext)
      servlet_context.getAttribute("rack.context").should be_a(ServletRackContext)

      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end

    it "initializes shared (thread-safe) by default" do
      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(servlet_context)

      rack_factory = servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(SharedRackApplicationFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end

    it "initializes shared (thread-safe) whem max runtimes is 1" do
      servlet_context.addInitParameter('jruby.max.runtimes', '1')

      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(servlet_context)

      rack_factory = servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(SharedRackApplicationFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      rack_factory.getApplication.should be_a(DefaultRackApplication)
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
    if ! servlet_context || servlet_context.is_a?(String)
      base = servlet_context.is_a?(String) ? servlet_context : nil
      servlet_context = new_servlet_context(base)
    end
    listener = org.jruby.rack.rails.RailsServletContextListener.new

    the_env = "GEM_HOME=#{ENV['GEM_HOME']},GEM_PATH=#{ENV['GEM_PATH']}"
    the_env << "\nRAILS_ENV=#{env}" if env
    servlet_context.addInitParameter("jruby.runtime.env", the_env)

    yield(servlet_context, listener) if block_given?
    listener.contextInitialized Java::JakartaServlet::ServletContextEvent.new(servlet_context)
    @rack_context = servlet_context.getAttribute("rack.context")
    @rack_factory = servlet_context.getAttribute("rack.factory")
    @servlet_context ||= servlet_context
  end

  def new_servlet_context(base_path = nil)
    servlet_context = org.jruby.rack.mock.RackLoggingMockServletContext.new base_path
    servlet_context.logger = raise_logger
    servlet_context
  end

  private

  GEMFILES_DIR = File.expand_path('../../../gemfiles', STUB_DIR)

  def copy_gemfile(name) # e.g. 'rails30'
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile")
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile.lock"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile.lock")
  end

end
