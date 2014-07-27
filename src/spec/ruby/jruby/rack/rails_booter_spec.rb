#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))
require 'jruby/rack/rails_booter'

describe JRuby::Rack::RailsBooter do

  before :all do

    require 'jruby/rack/rails/extensions'

    require 'active_support'

    require 'cgi/session/java_servlet_store'
    class ::CGI::Session::PStore; end

  end

  let(:booter) do
    JRuby::Rack::RailsBooter.new JRuby::Rack.context = @rack_context
  end

  after(:all) { JRuby::Rack.context = nil }

  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    booter.boot!
    booter.app_path.should == "./WEB-INF"
  end

  @@rails_env = ENV['RAILS_ENV']; @@rack_env = ENV['RACK_ENV']

  after do
    @@rails_env.nil? ? ENV.delete('RAILS_ENV') : ENV['RAILS_ENV'] = @@rails_env
    @@rack_env.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = @@rack_env
  end

  it "should default rails path to /WEB-INF" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/usr/apps/WEB-INF"
    booter.boot!
    booter.app_path.should == "/usr/apps/WEB-INF"
  end

  it "leaves ENV['RAILS_ENV'] as is if it was already set" do
    ENV['RAILS_ENV'] = 'staging'
    booter.boot!
    ENV['RAILS_ENV'].should == 'staging'
    booter.rails_env.should == "staging"
  end

  it "determines RAILS_ENV from the 'rails.env' init parameter" do
    ENV['RAILS_ENV'] = nil
    @rack_context.should_receive(:getInitParameter).with("rails.env").and_return "test"
    booter.boot!
    booter.rails_env.should == "test"
  end

  it "gets rails environment from rack environmnent" do
    ENV.delete('RAILS_ENV')
    ENV['RACK_ENV'] = 'development'
    @rack_context.stub(:getInitParameter)
    booter.boot!
    booter.rails_env.should == 'development'
  end

  it "default RAILS_ENV to 'production'" do
    ENV.delete('RAILS_ENV'); ENV.delete('RACK_ENV')
    booter.boot!
    booter.rails_env.should == "production"
  end

  it "should set RAILS_RELATIVE_URL_ROOT based on the servlet context path" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    booter.boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp'
  end

  it "should append to RAILS_RELATIVE_URL_ROOT if 'rails.relative_url_append' is set" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    @rack_context.should_receive(:getInitParameter).with("rails.relative_url_append").and_return "/blah"
    booter.boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp/blah'
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    booter.boot!
    booter.public_path.should == "."
  end

  it "should default public root to '/'" do
    @rack_context.should_receive(:getRealPath).with("/").and_return "."
    booter.boot!
    booter.public_path.should == "."
  end

  it "should create a log device that writes messages to the servlet context" do
    booter.boot!
    @rack_context.should_receive(:log).with(/hello/)
    booter.logger.instance_variable_get(:@logdev).write "hello"
  end

  describe "Rails 2.3", :lib => :stub do

    before do
      booter.stub(:rails2?).and_return true
    end

    it "sets up java servlet-based sessions if the session store is the default" do

      booter.boot!
      booter.should_receive(:rack_based_sessions?).and_return false

      booter.session_options[:database_manager] = ::CGI::Session::PStore
      booter.setup_sessions
      booter.session_options[:database_manager].should == ::CGI::Session::JavaServletStore
    end

    it "turns off Ruby CGI cookies if the java servlet store is used" do

      booter.boot!
      booter.should_receive(:rack_based_sessions?).and_return false

      booter.session_options[:database_manager] = ::CGI::Session::JavaServletStore
      booter.setup_sessions
      booter.session_options[:no_cookies].should == true
    end

    it "provides the servlet request in the session options if the java servlet store is used" do

      booter.boot!
      booter.should_receive(:rack_based_sessions?).twice.and_return false

      booter.session_options[:database_manager] = ::CGI::Session::JavaServletStore
      booter.setup_sessions
      booter.instance_variable_set :@load_environment, true

      ::Rack::Adapter::Rails.should_receive(:new).and_return app = double("rails adapter")
      app.should_receive(:call)

      env = { "java.servlet_request" => double("servlet request") }
      booter.to_app.call(env)
      env['rails.session_options'].should have_key(:java_servlet_request)
      env['rails.session_options'][:java_servlet_request].should == env["java.servlet_request"]
    end

    it "should set the PUBLIC_ROOT constant to the location of the public root",
      :lib => [ :rails23, :stub ] do

      booter.app_path = File.expand_path("../../../rails23", __FILE__)
      booter.boot!
      expect( PUBLIC_ROOT ).to eql booter.public_path
    end

    after(:each) do
      Object.send :remove_const, :PUBLIC_ROOT if Object.const_defined? :PUBLIC_ROOT
    end

    context 'booted' do

      before :each do
        $servlet_context = @servlet_context
        @rack_context.should_receive(:getContextPath).and_return "/foo"
        booter.app_path = File.expand_path("../../../rails23", __FILE__)
        booter.boot!
        silence_warnings { booter.load_environment }
      end

      after(:all) { $servlet_context = nil }

      it "should default the page cache directory to the public root" do
        ActionController::Base.page_cache_directory.should == booter.public_path
      end

      it "should default the session store to the java servlet session store" do
        ActionController::Base.session_store.should == CGI::Session::JavaServletStore
      end

      it "should set the ActionView ASSETS_DIR constant to the public root" do
        ActionView::Helpers::AssetTagHelper::ASSETS_DIR.should == booter.public_path
      end

      it "should set the ActionView JAVASCRIPTS_DIR constant to the public root/javascripts" do
        ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR.should == booter.public_path + "/javascripts"
      end

      it "should set the ActionView STYLESHEETS_DIR constant to the public root/stylesheets" do
        ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR.should == booter.public_path + "/stylesheets"
      end

      it "should set the ActionController.relative_url_root to the servlet context path" do
        ActionController::Base.relative_url_root.should == "/foo"
      end

    end

  end

  # NOTE: specs currently only test with a stubbed Rails::Railtie
  describe "Rails 3.x", :lib => :stub do

    before :each do
      $servlet_context = @servlet_context
      booter.app_path = File.expand_path("../../../rails3x", __FILE__)
      booter.boot!
      silence_warnings { booter.load_environment }
    end

    after :all do
      $servlet_context = nil
    end

    it "should have loaded the railtie" do
      defined?(JRuby::Rack::Railtie).should_not be nil
    end

    it "should set the application configuration's public path" do
      paths = {}
      for p in %w( public public/javascripts public/stylesheets )
        paths[p] = [p]
      end
      app = double("app"); app.stub_chain(:config, :paths).and_return(paths)
      public_path = Pathname.new(booter.public_path)

      Rails::Railtie.config.__before_configuration.size.should == 1
      before_config = Rails::Railtie.config.__before_configuration.first
      before_config.should_not be nil
      before_config.call(app)

      paths['public'].should == public_path.to_s
      paths['public/javascripts'].should == public_path.join("javascripts").to_s
      paths['public/stylesheets'].should == public_path.join("stylesheets").to_s
    end

    it "should not set the PUBLIC_ROOT constant" do
      lambda { PUBLIC_ROOT }.should raise_error
    end

    describe "logger" do

      before do
        @app = double "app"
        @app.stub(:config).and_return @config = double("config")
        @config.instance_eval do
          def logger; @logger; end
          def logger=(logger); @logger = logger; end
        end
      end

      it "has an initializer" do
        log_initializer.should_not be_nil
        log_initializer[1].should == [{:before => :initialize_logger}]
      end

      it "gets set as config.logger" do
        logger = Logger.new STDERR
        @config.stub(:log_level).and_return(:info)
        @config.stub(:log_formatter).and_return(nil)

        JRuby::Rack.should_receive(:logger).and_return(logger)
        #logger.class.should_receive(:const_get).with('INFO').and_return(nil)
        #logger.should_receive(:level=).with(nil)

        log_initializer.last.call(@app)
        @app.config.logger.should be(logger)
      end

      it "has a configurable log level and formatter" do
        @config.instance_eval do
          def logger; @logger; end
          def logger=(logger); @logger = logger; end
        end
        @config.stub(:log_formatter).and_return(nil)
        @config.should_receive(:log_level).and_return(:debug)
        @config.should_receive(:log_formatter).and_return(formatter = Logger::Formatter.new)

        log_initializer.last.call(@app) ##
        @app.config.logger.level.should be(Logger::DEBUG)
        @app.config.logger.formatter.should be(formatter)
      end

      it "is wrapped in tagged logging" do # Rails 3.2
        tagged_logging = ActiveSupport::TaggedLogging rescue nil
        begin
          klass = Class.new do # TaggedLogging stub
            def initialize(logger); @logger = logger end
          end
          ActiveSupport.const_set(:TaggedLogging, klass)
          @config.stub(:log_level).and_return(nil)
          @config.stub(:log_formatter).and_return(nil)

          log_initializer.last.call(@app)
          @app.config.logger.should be_a(klass)
          @app.config.logger.instance_variable_get(:@logger).should be_a(Logger)
        ensure
          if tagged_logging.nil?
            ActiveSupport.send :remove_const, :TaggedLogging
          else
            ActiveSupport.const_set(:TaggedLogging, tagged_logging)
          end
        end
      end

      private

      def log_initializer
        Rails::Railtie.__initializer.detect { |i| i[0] =~ /log/ }
      end

    end

    it "should return the Rails.application instance" do
      app = double "app"
      Rails.application = app
      booter.to_app.should == app
    end

    it "should set config.action_controller.relative_url_root based on ENV['RAILS_RELATIVE_URL_ROOT']" do
      ENV['RAILS_RELATIVE_URL_ROOT'] = '/blah'
      app = double "app"
      app.stub_chain(:config, :action_controller, :relative_url_root)
      app.config.action_controller.should_receive(:relative_url_root=).with("/blah")
      before_config = Rails::Railtie.__initializer.detect { |i| i.first =~ /url/ }
      before_config.should_not be_nil
      before_config[1].should == [{:after => "action_controller.set_configs"}]
      before_config.last.call(app)
    end
  end

  # NOTE: specs currently only test with a stubbed Rails::Railtie
  describe "Rails 3.1", :lib => [ :stub ] do

    before :each do
      $servlet_context = @servlet_context
      booter.app_path = File.expand_path("../../../rails3x", __FILE__)
      booter.boot!
      booter.load_environment
    end

    after :all do
      $servlet_context = nil
    end

    #
    # relative_url_root= has been deprecated in Rails > 3. We should not call it when it's not defined.
    # See: https://github.com/jruby/jruby-rack/issues/73
    #      https://github.com/rails/rails/issues/2435
    #
    it "should not set config.action_controller.relative_url_root if the controller doesn't respond to that method" do
      ENV['RAILS_RELATIVE_URL_ROOT'] = '/blah'
      app = double "app"
      app.stub_chain(:config, :action_controller, :respond_to?)
      # obviously this only tests whatever rails version is loaded
      # I'm unsure of the best way right now
      if ActionController::Base.respond_to?(:relative_url_root=)
        app.config.action_controller.should_receive(:relative_url_root=)
      else
        app.config.action_controller.should_not_receive(:relative_url_root=)
      end

      init = Rails::Railtie.__initializer.detect { |i| i.first =~ /url/ }
      init.should_not be nil
      init[1].should == [{:after => "action_controller.set_configs"}]
      init.last.call(app)
    end
  end

end if defined? Rails

describe JRuby::Rack, "Rails controller extensions" do

  before :all do
    require 'action_controller'
  end

  before :each do
    @controller = ActionController::Base.new
    @controller.stub(:request).and_return(request = double("request"))
    @controller.stub(:response).and_return(response = double("response"))
    request.stub(:env).and_return({"java.servlet_request" => (@servlet_request = double("servlet request"))})
    @headers = {}
    response.stub(:headers).and_return @headers
  end

  it "should add a #servlet_request method to ActionController::Base" do
    @controller.should respond_to(:servlet_request)
    @controller.servlet_request.should == @servlet_request
  end

  it "should add a #forward_to method for forwarding to another servlet" do
    @servlet_response = double "servlet response"
    @controller.request.should_receive(:forward_to).with("/forward.jsp")

    @controller.forward_to "/forward.jsp"
  end

end if defined? Rails
