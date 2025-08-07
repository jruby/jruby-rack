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

  it "uses JRuby-Rack's logger by default" do
    booter.boot!
    expect( booter.logger ).to_not be nil
    expect( booter.logger ).to be JRuby::Rack.logger
    booter.logger.info 'hello-there'
  end

  RAILS_ROOT_DIR = File.expand_path("../../../rails3x", __FILE__)

  # NOTE: specs currently only test with a stubbed Rails::Railtie
  describe "Rails 3.x", :lib => :stub do

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
        logger = JRuby::Rack::Logger.new STDERR
        @config.stub(:log_level).and_return(:info)
        @config.stub(:log_formatter).and_return(nil)

        JRuby::Rack.should_receive(:logger).and_return(logger)
        #logger.class.should_receive(:const_get).with('INFO').and_return(nil)
        #logger.should_receive(:level=).with(nil)

        log_initializer.last.call(@app)
        @app.config.logger.should be(logger)
      end

      it "has a configurable log level" do
        @config.instance_eval do
          def logger; @logger; end
          def logger=(logger); @logger = logger; end
        end
        @config.stub(:log_formatter).and_return(nil)
        @config.should_receive(:log_level).and_return(:debug)

        log_initializer.last.call(@app) ##
        @app.config.logger.level.should be(JRuby::Rack::Logger::DEBUG)
      end

      it "is wrapped in tagged logging" do # Rails 3.2
        active_support = defined? ::ActiveSupport
        tagged_logging = active_support && ActiveSupport::TaggedLogging rescue nil
        begin
          klass = Class.new do # TaggedLogging stub
            def initialize(logger); @logger = logger end
          end
          module ::ActiveSupport; end
          ::ActiveSupport.const_set(:TaggedLogging, klass)
          @config.stub(:log_level).and_return(nil)
          @config.stub(:log_formatter).and_return(nil)

          log_initializer.last.call(@app)
          @app.config.logger.should be_a(klass)
          @app.config.logger.instance_variable_get(:@logger).should be_a(JRuby::Rack::Logger)
        ensure
          if tagged_logging.nil?
            if active_support
              ActiveSupport.send :remove_const, :TaggedLogging
            else
              Object.send :remove_const, :ActiveSupport rescue nil
            end
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
