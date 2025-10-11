#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))
require 'jruby/rack/rails_booter'

describe JRuby::Rack::RailsBooter do

  let(:real_logger) do
    org.jruby.rack.logging.BufferLogger.new
  end

  let(:booter) do
    JRuby::Rack.logger = JRuby::Rack::Logger.new(real_logger)
    JRuby::Rack.context = @rack_context
    JRuby::Rack::RailsBooter.new @rack_context
  end

  after { JRuby::Rack.context = nil; JRuby::Rack.logger = nil }

  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    expect(@rack_context).to receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    booter.boot!
    expect(booter.app_path).to eq "./WEB-INF"
  end

  before do
    @original_rails_env = ENV['RAILS_ENV']
    @original_rack_env = ENV['RACK_ENV']
  end

  after do
    @original_rails_env.nil? ? ENV.delete('RAILS_ENV') : ENV['RAILS_ENV'] = @original_rails_env
    @original_rack_env.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = @original_rack_env
  end

  it "should default rails path to /WEB-INF" do
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "/usr/apps/WEB-INF"
    booter.boot!
    expect(booter.app_path).to eq "/usr/apps/WEB-INF"
  end

  it "leaves ENV['RAILS_ENV'] as is if it was already set" do
    ENV['RAILS_ENV'] = 'staging'
    booter.boot!
    expect(ENV['RAILS_ENV']).to eq 'staging'
    expect(booter.rails_env).to eq "staging"
  end

  it "determines RAILS_ENV from the 'rails.env' init parameter" do
    ENV['RAILS_ENV'] = nil
    expect(@rack_context).to receive(:getInitParameter).with("rails.env").and_return "test"
    booter.boot!
    expect(booter.rails_env).to eq "test"
  end

  it "gets rails environment from rack environmnent" do
    ENV.delete('RAILS_ENV')
    ENV['RACK_ENV'] = 'development'
    allow(@rack_context).to receive(:getInitParameter)
    booter.boot!
    expect(booter.rails_env).to eq 'development'
  end

  it "default RAILS_ENV to 'production'" do
    ENV.delete('RAILS_ENV'); ENV.delete('RACK_ENV')
    booter.boot!
    expect(booter.rails_env).to eq "production"
  end

  it "should set RAILS_RELATIVE_URL_ROOT based on the servlet context path" do
    expect(@rack_context).to receive(:getContextPath).and_return '/myapp'
    booter.boot!
    expect(ENV['RAILS_RELATIVE_URL_ROOT']).to eq '/myapp'
  end

  it "should append to RAILS_RELATIVE_URL_ROOT if 'rails.relative_url_append' is set" do
    expect(@rack_context).to receive(:getContextPath).and_return '/myapp'
    expect(@rack_context).to receive(:getInitParameter).with("rails.relative_url_append").and_return "/blah"
    booter.boot!
    expect(ENV['RAILS_RELATIVE_URL_ROOT']).to eq '/myapp/blah'
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    expect(@rack_context).to receive(:getInitParameter).with("public.root").and_return "/blah"
    expect(@rack_context).to receive(:getRealPath).with("/blah").and_return "."
    booter.boot!
    expect(booter.public_path).to eq "."
  end

  it "should default public root to '/'" do
    expect(@rack_context).to receive(:getRealPath).with("/").and_return "."
    booter.boot!
    expect(booter.public_path).to eq "."
  end

  RAILS_ROOT_DIR = File.expand_path("../../../rails", __FILE__)

  describe "Rails (stubbed)", :lib => :stub do
    # NOTE: specs currently only test with a stubbed Rails::Railtie

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
      [:app_path, :public_path, :context].each do |name|
        JRuby::Rack.send :remove_instance_variable, :"@#{name}"
      end
    end

    after :all do
      $servlet_context = nil
    end

    let(:railtie_class) { Class.new(Rails::Railtie) }

    it "should have loaded the railtie" do
      expect(defined?(JRuby::Rack::Railtie)).not_to be nil
    end

    it "should set the application configuration's public path" do
      paths = %w( public public/javascripts public/stylesheets ).inject({}) do
      |hash, path|
        hash[path] = [File.join(RAILS_ROOT_DIR, path)]; hash
      end
      app = double("app")
      expect(app).to receive_message_chain(:config, :paths).and_return(paths)
      public_path = Pathname.new(booter.public_path)

      expect(railtie_class.config.__before_configuration.size).to eq 1
      before_config = railtie_class.config.__before_configuration.first
      expect(before_config).not_to be nil

      before_config.call(app)

      expect(paths['public']).to eq public_path.to_s
      expect(paths['public/javascripts']).to eq public_path.join("javascripts").to_s
      expect(paths['public/stylesheets']).to eq public_path.join("stylesheets").to_s
    end

    it "works when JRuby::Rack.public_path is nil (public does not exist)" do
      paths = %w( public public/javascripts public/stylesheets ).inject({}) do
      |hash, path|
        hash[path] = [path.sub('public', 'NO-SUCH-DiR')]; hash
      end
      app = double("app")
      JRuby::Rack.public_path = nil

      before_config = railtie_class.config.__before_configuration.first
      expect(before_config).not_to be nil
      before_config.call(app)

      expect(paths['public']).to eq [public_path = "NO-SUCH-DiR"]
      expect(paths['public/javascripts']).to eq [File.join(public_path, "javascripts")]
      expect(paths['public/stylesheets']).to eq [File.join(public_path, "stylesheets")]
    end

    describe "logger" do

      before(:all) do
        @active_support = defined? ::ActiveSupport
        @active_support = ::ActiveSupport.constants if @active_support
        require 'active_support/logger'
      end

      after(:all) do
        if @active_support
          [:Logger, :TaggedLogging, :LoggerSilence, :LoggerThreadSafeLevel].each do |name|
            # stubbed bits we might end up loading
            ActiveSupport.send :remove_const, name unless @active_support.include?(name)
          end
        else
          Object.send :remove_const, :ActiveSupport rescue nil
        end
      end

      before do
        @app = double "app"
        allow(@app).to receive(:config).and_return @config = double("config")
        @config.instance_eval do
          def logger
            @logger;
          end

          def logger=(logger)
            ; @logger = logger;
          end
        end
      end

      it "has an initializer" do
        expect(log_initializer).not_to be_nil
        expect(log_initializer[1]).to eq [{ :before => :initialize_logger }]
      end

      it "gets set as config.logger (wrapped with tagged logging and logger_silence)" do
        allow(@config).to receive(:log_level).and_return(nil)
        allow(@config).to receive(:log_formatter).and_return(nil)

        log_initializer.last.call(@app)
        rails_logger = @app.config.logger
        # ActiveSupport::TaggedLogging.new clones the original logger instance
        expect(rails_logger).to be_a(JRuby::Rack::Logger)
        expect(rails_logger).to be_a(ActiveSupport::TaggedLogging)
        if defined? ActiveSupport::LoggerSilence
          expect(rails_logger).to be_a(ActiveSupport::LoggerSilence)
          expect(rails_logger.silencer).to be true
          # sanity check silence works:
          value_returned = rails_logger.silence(Logger::WARN) { |logger| logger.class.name }
          expect(value_returned).to eql('JRuby::Rack::RailsLogger')
        end
        expect(rails_logger.level).to be(nil) # should not be set unless user configured `config.log_level`
      end

      it "has a configurable log level" do
        # @config.instance_eval do
        #   def logger; @logger; end
        #   def logger=(logger); @logger = logger; end
        # end
        allow(@config).to receive(:log_formatter).and_return(nil)
        expect(@config).to receive(:log_level).and_return(:error)

        log_initializer.last.call(@app)
        rails_logger = @app.config.logger
        expect(rails_logger.level).to be(JRuby::Rack::Logger::ERROR)
      end

      private

      def log_initializer
        Rails::Railtie.__initializer.detect { |i| i[0] =~ /log/ }
      end

    end

    it "should return the Rails.application instance" do
      app = double "app"
      Rails.application = app
      expect(booter.to_app).to eq app
    end

  end # if defined? Rails

end

describe JRuby::Rack, "Rails controller extensions" do

  before(:all) { require 'jruby/rack/rails/extensions' }

  let(:controller) do
    controller = ActionController::Base.new
    allow(controller).to receive(:request).and_return request
    allow(controller).to receive(:response).and_return response
    controller
  end

  let(:request) { double("request") }
  let(:response) { double("response") }

  let(:servlet_request) { org.springframework.mock.web.MockHttpServletRequest.new }
  let(:servlet_response) { org.springframework.mock.web.MockHttpServletResponse.new }

  before :each do
    allow(request).to receive(:env).and_return({
                                                 'java.servlet_request' => servlet_request,
                                                 'java.servlet_response' => servlet_response
                                               })
    allow(response).to receive(:headers).and_return @headers = {}
  end

  it "should add a #servlet_request method to ActionController::Base" do
    expect(controller).to respond_to(:servlet_request)
    expect(controller.servlet_request).to eq servlet_request
  end

  it "should add a #servlet_response method to ActionController::Base" do
    expect(controller).to respond_to(:servlet_response)
    expect(controller.servlet_response).to eq servlet_response
  end

  it "should add a #forward_to method for forwarding to another servlet" do
    #@servlet_response = double "servlet response"
    expect(controller.request).to receive(:forward_to).with("/forward.jsp")
    controller.forward_to '/forward.jsp'
  end

end if defined? Rails
