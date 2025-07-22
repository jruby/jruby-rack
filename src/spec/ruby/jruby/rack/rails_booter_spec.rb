#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))
require 'jruby/rack/rails_booter'

describe JRuby::Rack::RailsBooter do

  let(:booter) do
    real_logger = org.jruby.rack.logging.BufferLogger.new
    JRuby::Rack.logger = JRuby::Rack::Logger.new real_logger
    JRuby::Rack::RailsBooter.new JRuby::Rack.context = @rack_context
  end

  let(:rails_booter) do
    rails_booter = booter; def rails_booter.rails2?; nil end; rails_booter
  end

  after { JRuby::Rack.context = nil; JRuby::Rack.logger = nil }

  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    rails_booter.boot!
    rails_booter.app_path.should == "./WEB-INF"
  end

  before do
    @rails_env = ENV['RAILS_ENV']
    @rack_env = ENV['RACK_ENV']
  end

  after do
    @rails_env.nil? ? ENV.delete('RAILS_ENV') : ENV['RAILS_ENV'] = @rails_env
    @rack_env.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = @rack_env
  end

  it "should default rails path to /WEB-INF" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/usr/apps/WEB-INF"
    rails_booter.boot!
    rails_booter.app_path.should == "/usr/apps/WEB-INF"
  end

  it "leaves ENV['RAILS_ENV'] as is if it was already set" do
    ENV['RAILS_ENV'] = 'staging'
    rails_booter.boot!
    ENV['RAILS_ENV'].should == 'staging'
    rails_booter.rails_env.should == "staging"
  end

  it "determines RAILS_ENV from the 'rails.env' init parameter" do
    ENV['RAILS_ENV'] = nil
    @rack_context.should_receive(:getInitParameter).with("rails.env").and_return "test"
    rails_booter.boot!
    rails_booter.rails_env.should == "test"
  end

  it "gets rails environment from rack environmnent" do
    ENV.delete('RAILS_ENV')
    ENV['RACK_ENV'] = 'development'
    @rack_context.stub(:getInitParameter)
    rails_booter.boot!
    rails_booter.rails_env.should == 'development'
  end

  it "default RAILS_ENV to 'production'" do
    ENV.delete('RAILS_ENV'); ENV.delete('RACK_ENV')
    rails_booter.boot!
    rails_booter.rails_env.should == "production"
  end

  it "should set RAILS_RELATIVE_URL_ROOT based on the servlet context path" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    rails_booter.boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp'
  end

  it "should append to RAILS_RELATIVE_URL_ROOT if 'rails.relative_url_append' is set" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    @rack_context.should_receive(:getInitParameter).with("rails.relative_url_append").and_return "/blah"
    rails_booter.boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp/blah'
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    rails_booter.boot!
    rails_booter.public_path.should == "."
  end

  it "should default public root to '/'" do
    @rack_context.should_receive(:getRealPath).with("/").and_return "."
    rails_booter.boot!
    rails_booter.public_path.should == "."
  end

  RAILS_ROOT_DIR = File.expand_path("../../../rails", __FILE__)

  # NOTE: specs currently only test with a stubbed Rails::Railtie
  describe "Rails (stubbed)", :lib => :stub do

    before :all do
      $LOAD_PATH.unshift File.join(RAILS_ROOT_DIR, 'stub') # for require 'rails/railtie'
    end

    before :each do
      $servlet_context = @servlet_context
      booter.layout_class = JRuby::Rack::FileSystemLayout
      booter.app_path = RAILS_ROOT_DIR.dup
      booter.boot!
      silence_warnings { booter.load_environment }
    end

    after :each do
      [ :app_path, :public_path, :context ].each do |name|
        JRuby::Rack.send :remove_instance_variable, :"@#{name}"
      end
    end

    after :all do
      $servlet_context = nil
    end

    it "should have loaded the railtie" do
      defined?(JRuby::Rack::Railtie).should_not be nil
    end

    it "should set the application configuration's public path" do
      paths = %w( public public/javascripts public/stylesheets ).inject({}) do
        |hash, path| hash[ path ] = [ File.join(RAILS_ROOT_DIR, path) ]; hash
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

    it "works when JRuby::Rack.public_path is nil (public does not exist)" do
      paths = %w( public public/javascripts public/stylesheets ).inject({}) do
        |hash, path| hash[ path ] = [ path.sub('public', 'NO-SUCH-DiR') ]; hash
      end
      app = double("app"); app.stub_chain(:config, :paths).and_return(paths)
      JRuby::Rack.public_path = nil

      before_config = Rails::Railtie.config.__before_configuration.first
      before_config.should_not be nil
      before_config.call(app)

      paths['public'].should == [ public_path = "NO-SUCH-DiR" ]
      paths['public/javascripts'].should == [ File.join(public_path, "javascripts") ]
      paths['public/stylesheets'].should ==[ File.join(public_path, "stylesheets") ]
    end

    describe "logger" do

      before(:all) do
        @active_support = defined? ::ActiveSupport
        @active_support = ::ActiveSupport.constants if @active_support
        require 'active_support/logger'
      end

      after(:all) do
        if @active_support
          [:Logger, :TaggedLogging, :LoggerSilence, :LoggerThreadSafeLevel].each do |name| # stubbed bits we might end up loading
            ActiveSupport.send :remove_const, name unless @active_support.include?(name)
          end
        else
          Object.send :remove_const, :ActiveSupport rescue nil
        end
      end

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

      it "gets set as config.logger (wrapped with tagged logging and logger_silence)" do
        logger = JRuby::Rack::Logger.new STDERR
        @config.stub(:log_level).and_return(:info)
        @config.stub(:log_formatter).and_return(nil)

        JRuby::Rack.should_receive(:logger).and_return(logger)

        log_initializer.last.call(@app)
        rails_logger = @app.config.logger
        # ActiveSupport::TaggedLogging.new clones the original logger instance
        expect(rails_logger).to be_a(JRuby::Rack::Logger)
        expect(rails_logger).to be_a(ActiveSupport::TaggedLogging)
        if defined? ActiveSupport::LoggerSilence
          expect(rails_logger).to be_a(ActiveSupport::LoggerSilence)
          # sanity check silence works:
          value_returned = rails_logger.silence(Logger::WARN) { |logger| logger.class.name }
          expect(value_returned).to eql('JRuby::Rack::Logger')
        end
      end

      it "has a configurable log level" do
        @config.instance_eval do
          def logger; @logger; end
          def logger=(logger); @logger = logger; end
        end
        @config.stub(:log_formatter).and_return(nil)
        @config.should_receive(:log_level).and_return(:error)

        log_initializer.last.call(@app) ##
        @app.config.logger.level.should be(JRuby::Rack::Logger::ERROR)
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

  end # if defined? Rails

  # NOTE: specs currently only test with a stubbed Rails::Railtie
  describe "Rails 3.1", :lib => [ :stub ] do

    before :each do
      $servlet_context = @servlet_context
      #booter.layout_class = JRuby::Rack::FileSystemLayout
      booter.app_path = RAILS_ROOT_DIR.dup
      def booter.rails2?; false end
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
      require 'action_controller' # stub
      begin
        #ActionController::Base.send :remove_method, :relative_url_root=
        ENV['RAILS_RELATIVE_URL_ROOT'] = '/blah'
        app = double "app"
        app.stub_chain(:config, :action_controller)
        app.config.stub(:action_controller).and_return(nil)
        # app.config.action_controller.should_not_receive(:relative_url_root=)
        ActionController::Base.stub(:config).and_return app.config

        app.config.should_receive(:relative_url_root=).with('/blah')
        ActionController::Base.should_not_receive(:relative_url_root=)

        init = Rails::Railtie.__initializer.detect { |i| i.first =~ /url/ }
        init.should_not be nil
        init[1].should == [{:after => "action_controller.set_configs"}]
        init.last.call(app)
      ensure
        #ActionController::Base.send :attr_writer, :relative_url_root
      end
    end

  end # if defined? Rails

end

describe JRuby::Rack, "Rails controller extensions" do

  before(:all) { require 'jruby/rack/rails/extensions' }

  let(:controller) do
    controller = ActionController::Base.new
    controller.stub(:request).and_return request
    controller.stub(:response).and_return response
    controller
  end

  let(:request) { double("request") }
  let(:response) { double("response") }

  let(:servlet_request) { org.springframework.mock.web.MockHttpServletRequest.new }
  let(:servlet_response) { org.springframework.mock.web.MockHttpServletResponse.new }

  before :each do
    request.stub(:env).and_return({
        'java.servlet_request' => servlet_request,
        'java.servlet_response' => servlet_response
    })
    response.stub(:headers).and_return @headers = {}
  end

  it "should add a #servlet_request method to ActionController::Base" do
    controller.should respond_to(:servlet_request)
    controller.servlet_request.should == servlet_request
  end

  it "should add a #servlet_response method to ActionController::Base" do
    controller.should respond_to(:servlet_response)
    controller.servlet_response.should == servlet_response
  end

  it "should add a #forward_to method for forwarding to another servlet" do
    #@servlet_response = double "servlet response"
    controller.request.should_receive(:forward_to).with("/forward.jsp")
    controller.forward_to '/forward.jsp'
  end

end if defined? Rails
