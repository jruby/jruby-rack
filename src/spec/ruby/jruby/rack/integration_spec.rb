
require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'fileutils'
require 'jruby'

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

  #after(:all) { JRuby::Rack.context = nil }

  describe 'rack (lambda)' do

    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new "file://#{STUB_DIR}/rack"
      @servlet_context.logger = raise_logger
      #@servlet_context.logger = org.jruby.rack.logging.StandardOutLogger.new("")
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
        listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)
        @rack_context = @servlet_context.getAttribute("rack.context")
        @rack_factory = @servlet_context.getAttribute("rack.factory")
      end

      it "inits servlet" do
        servlet_config = org.jruby.rack.mock.MockServletConfig.new @servlet_context

        servlet = org.jruby.rack.RackServlet.new
        servlet.init(servlet_config)
        expect( servlet.getContext ).to_not be nil
        expect( servlet.getDispatcher ).to_not be nil
      end

      it "serves (servlet)" do
        dispatcher = org.jruby.rack.DefaultRackDispatcher.new(@rack_context)
        servlet = org.jruby.rack.RackServlet.new(dispatcher, @rack_context)

        request = org.jruby.rack.mock.MockHttpServletRequest.new(@servlet_context)
        request.setMethod("GET")
        request.setRequestURI("/")
        request.setContentType("text/html")
        request.setContent("".to_java.bytes)
        response = org.jruby.rack.mock.MockHttpServletResponse.new

        servlet.service(request, response)

        expect( response.getStatus ).to eql 200
        expect( response.getContentType ).to eql 'text/plain'
        expect( response.getContentAsString ).to eql 'OK'
        expect( response.getHeader("Via") ).to eql 'JRuby-Rack'
      end

    end

  end

  shared_examples_for 'a rails app', :shared => true do

    let(:servlet_context) do
      servlet_context = org.jruby.rack.mock.MockServletContext.new base_path
      servlet_context.logger = raise_logger
      set_compat_version servlet_context
      servlet_context
    end

    it "initializes (pooling by default)" do
      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)

      rack_factory = servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(PoolingRackApplicationFactory)
      rack_factory.should respond_to(:realFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      servlet_context.getAttribute("rack.context").should be_a(RackContext)
      servlet_context.getAttribute("rack.context").should be_a(ServletRackContext)

      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end

    it "initializes threadsafe!" do
      servlet_context.addInitParameter('jruby.max.runtimes', '1')

      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)

      rack_factory = servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(SharedRackApplicationFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end

  end

  describe 'rails 3.0', :lib => :rails30 do

    before(:all) { copy_gemfile("rails30") }

    let(:base_path) { "file://#{STUB_DIR}/rails30" }

    it_should_behave_like 'a rails app'

    context "initialized" do

      before :all do
        initialize_rails nil, base_path
      end

      it "loaded rack ~> 1.2" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.2'
      end

      it "disables rack's chunked support (by default)" do
        @runtime = @rack_factory.getApplication.getRuntime
        expect_to_have_monkey_patched_chunked
      end

    end

    context "initialized (custom)" do

      before :all do
        initialize_rails 'custom', base_path
      end

      it "booted a custom env with a custom logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_eql_to "Rails.env", 'custom'
        should_eval_as_not_nil "Rails.logger"
        should_eval_as_eql_to "Rails.logger.class.name", 'CustomLogger'
      end

    end

  end

  describe 'rails 3.1', :lib => :rails31 do

    before(:all) { copy_gemfile("rails31") }

    let(:base_path) { "file://#{STUB_DIR}/rails31" }

    it_should_behave_like 'a rails app'

    context "initialized" do

      before :all do
        initialize_rails 'production', base_path
      end

      it "loaded META-INF/init.rb" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(WARBLER_CONFIG)"
      end

      it "loaded rack ~> 1.3" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.3'
      end

      it "booted with a servlet logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_not_nil "Rails.logger"
        should_eval_as_not_nil "Rails.logger.instance_variable_get(:'@logdev')" # Logger::LogDevice
        should_eval_as_eql_to "Rails.logger.instance_variable_get(:'@logdev').dev.class.name", 'JRuby::Rack::ServletLog'

        should_eval_as_eql_to "Rails.logger.level", Logger::DEBUG
      end

      it "disables rack's chunked support (by default)" do
        @runtime = @rack_factory.getApplication.getRuntime
        expect_to_have_monkey_patched_chunked
      end

    end

  end

  describe 'rails 3.2', :lib => :rails32 do

    before(:all) { copy_gemfile("rails32") }

    let(:base_path) { "file://#{STUB_DIR}/rails32" }

    it_should_behave_like 'a rails app'

    context "initialized" do

      before :all do
        initialize_rails 'production', base_path
      end

      it "loaded rack ~> 1.4" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.4'
      end

      it "booted with a servlet logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_not_nil "Rails.logger"
        should_eval_as_eql_to "Rails.logger.class.name", 'ActiveSupport::TaggedLogging'
        should_eval_as_not_nil "Rails.logger.instance_variable_get(:'@logger')"
        should_eval_as_eql_to "logger = Rails.logger.instance_variable_get(:'@logger'); " +
          "logger.instance_variable_get(:'@logdev').dev.class.name", 'JRuby::Rack::ServletLog'

        should_eval_as_eql_to "Rails.logger.level", Logger::INFO
      end

      it "sets up public_path (as for a war)" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_eql_to "Rails.public_path", "#{STUB_DIR}/rails32"
        # make sure it was set early on (before initializers run) :
        should_eval_as_not_nil "defined? Rails32::Application::PUBLIC_PATH"
        should_eval_as_eql_to "Rails32::Application::PUBLIC_PATH", "#{STUB_DIR}/rails32"
        # check if image_tag resolves path to images correctly :
        should_eval_as_eql_to %q{
          config = ActionController::Base.config;
          asset_paths = ActionView::Helpers::AssetTagHelper::AssetPaths.new(config);
          image_path = asset_paths.compute_public_path('image.jpg', 'images');
          image_path[0, 18]
        }, '/images/image.jpg?'
      end

      it "disables rack's chunked support (by default)" do
        @runtime = @rack_factory.getApplication.getRuntime
        expect_to_have_monkey_patched_chunked
      end

    end

  end

  describe 'rails 4.0', :lib => :rails40 do

    before(:all) { copy_gemfile("rails40") }

    let(:base_path) { "file://#{STUB_DIR}/rails40" }

    it_should_behave_like 'a rails app'

    context "initialized" do

      before :all do
        initialize_rails 'production', base_path
      end

      it "loaded rack ~> 1.5" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.5'
      end

      it "booted with a servlet logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_not_nil "Rails.logger"
        # NOTE: TaggedLogging is a module that extends the instance now :
        should_eval_as_eql_to "Rails.logger.is_a? ActiveSupport::TaggedLogging", true
        should_eval_as_eql_to "Rails.logger.instance_variable_get(:'@logdev').dev.class.name",
                              'JRuby::Rack::ServletLog'
        should_eval_as_eql_to "Rails.logger.level", Logger::INFO
      end

      it "sets up public_path (as for a war)" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_eql_to "Rails.public_path.to_s", "#{STUB_DIR}/rails40" # Pathname
        should_eval_as_eql_to %q{
          config = ActionController::Base.config;
          asset_paths = ActionView::Helpers::AssetTagHelper::AssetPaths.new(config);
          image_path = asset_paths.compute_public_path('image.jpg', 'images');
          image_path[0, 18]
        }, '/images/image.jpg?'
      end

    end

  end

  describe 'rails 2.3', :lib => :rails23 do

    before(:all) do
      copy_gemfile('rails23')
      path = File.join(STUB_DIR, 'rails23/WEB-INF/init.rb') # hard-coded RAILS_GEM_VERSION
      File.open(path, 'w') { |f| f << "RAILS_GEM_VERSION = '#{Rails::VERSION::STRING}'\n" }
    end

    let(:base_path) { "file://#{STUB_DIR}/rails23" }

    it_should_behave_like 'a rails app'

    context "initialized" do

      before :all do
        initialize_rails nil, base_path
      end

      it "loaded rack ~> 1.1" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.1'
      end

      it "booted with a servlet logger" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rails)"
        should_eval_as_not_nil "defined?(Rails.logger)"

        should_eval_as_not_nil "defined?(ActiveSupport::BufferedLogger) && Rails.logger.is_a?(ActiveSupport::BufferedLogger)"
        should_eval_as_not_nil "Rails.logger.send(:instance_variable_get, '@log')"
        should_eval_as_eql_to "log = Rails.logger.send(:instance_variable_get, '@log');" +
                              "log.class.name", 'JRuby::Rack::ServletLog'
        should_eval_as_eql_to "Rails.logger.level", Logger::INFO

        @runtime.evalScriptlet "Rails.logger.debug 'logging works'"
      end

    end

  end

  def expect_to_have_monkey_patched_chunked
    @runtime.evalScriptlet "require 'rack/chunked'"
    script = %{
      headers = { 'Transfer-Encoding' => 'chunked' }

      body = [ \"1\".freeze, \"\", \"\nsecond\" ]

      if defined? Rack::Chunked::Body # Rails 3.x
        body = Rack::Chunked::Body.new body
      else # Rack 1.1 / 1.2
        chunked = Rack::Chunked.new(nil)
        chunked.chunk(200, headers, body)
        body = chunked
      end

      parts = []; body.each { |part| parts << part }
      parts.join
    }
    should_eval_as_eql_to script, "1\nsecond"
  end

  def initialize_rails(env = nil, servlet_context = @servlet_context)
    if ! servlet_context || servlet_context.is_a?(String)
      base = servlet_context.is_a?(String) ? servlet_context : nil
      servlet_context = new_servlet_context(base)
    end
    listener = org.jruby.rack.rails.RailsServletContextListener.new
    yield(servlet_context, listener) if block_given?
    listener.contextInitialized javax.servlet.ServletContextEvent.new(servlet_context)
    @rack_context = servlet_context.getAttribute("rack.context")
    @rack_factory = servlet_context.getAttribute("rack.factory")
    # Travis-CI might have RAILS_ENV=test set, which is not desired for us :
    #if ENV['RAILS_ENV'] || ENV['RACK_ENV']
    servlet_context.addInitParameter("jruby.runtime.env", '')
    #end
    servlet_context.addInitParameter("rails.env", env.to_s) if env
    @servlet_context ||= servlet_context
  end

  def new_servlet_context(base_path = nil)
    servlet_context = org.jruby.rack.mock.MockServletContext.new base_path
    servlet_context.logger = raise_logger
    set_compat_version servlet_context
    servlet_context
  end

  def set_compat_version(servlet_context = @servlet_context)
    if JRuby.runtime.is1_9
      servlet_context.addInitParameter("jruby.compat.version", '1.9')
    else
      servlet_context.addInitParameter("jruby.compat.version", '1.8')
    end
  end

  private

  GEMFILES_DIR = File.expand_path('../../../gemfiles', STUB_DIR)

  def copy_gemfile(name) # e.g. 'rails30'
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile")
    FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile.lock"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile.lock")
  end

end
