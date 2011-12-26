#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'jruby/rack/rails'
require 'jruby/rack/rails/extensions'
require 'cgi/session/java_servlet_store'
class ::CGI::Session::PStore; end

describe JRuby::Rack::RailsBooter do
  
  it "should determine RAILS_ROOT from the 'rails.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("rails.root").and_return "/WEB-INF"
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.app_path.should == "./WEB-INF"
  end

  it "should default RAILS_ROOT to /WEB-INF" do
    @rack_context.should_receive(:getRealPath).with("/WEB-INF").and_return "./WEB-INF"
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.app_path.should == "./WEB-INF"
  end

  it "should leave ENV['RAILS_ENV'] as is if it was already set" do
    ENV['RAILS_ENV'] = 'staging'
    create_booter(JRuby::Rack::RailsBooter).boot!
    ENV['RAILS_ENV'].should == 'staging'
    @booter.rails_env.should == "staging"
  end

  it "should determine RAILS_ENV from the 'rails.env' init parameter" do
    ENV['RAILS_ENV'] = nil
    @rack_context.should_receive(:getInitParameter).with("rails.env").and_return "test"
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.rails_env.should == "test"
  end

  it "should default RAILS_ENV to 'production'" do
    ENV['RAILS_ENV'] = nil
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.rails_env.should == "production"
  end

  it "should set RAILS_RELATIVE_URL_ROOT based on the servlet context path" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    create_booter(JRuby::Rack::RailsBooter).boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp'
  end

  it "should append to RAILS_RELATIVE_URL_ROOT if 'rails.relative_url_append' is set" do
    @rack_context.should_receive(:getContextPath).and_return '/myapp'
    @rack_context.should_receive(:getInitParameter).with("rails.relative_url_append").and_return "/blah"
    create_booter(JRuby::Rack::RailsBooter).boot!
    ENV['RAILS_RELATIVE_URL_ROOT'].should == '/myapp/blah'
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @rack_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @rack_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.public_path.should == "."
  end

  it "should default public root to '/'" do
    @rack_context.should_receive(:getRealPath).with("/").and_return "."
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.public_path.should == "."
  end

  it "should create a log device that writes messages to the servlet context" do
    create_booter(JRuby::Rack::RailsBooter).boot!
    @rack_context.should_receive(:log).with(/hello/)
    @booter.logdev.write "hello"
  end
  
  it "should setup java servlet-based sessions if the session store is the default" do
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.should_receive(:rack_based_sessions?).and_return false
    
    @booter.session_options[:database_manager] = ::CGI::Session::PStore
    @booter.setup_sessions
    @booter.session_options[:database_manager].should == ::CGI::Session::JavaServletStore
  end

  it "should turn off Ruby CGI cookies if the java servlet store is used" do
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.should_receive(:rack_based_sessions?).and_return false
    
    @booter.session_options[:database_manager] = ::CGI::Session::JavaServletStore
    @booter.setup_sessions
    @booter.session_options[:no_cookies].should == true
  end
    
  it "should provide the servlet request in the session options if the java servlet store is used" do
    create_booter(JRuby::Rack::RailsBooter).boot!
    @booter.should_receive(:rack_based_sessions?).twice.and_return false
    
    @booter.session_options[:database_manager] = ::CGI::Session::JavaServletStore
    @booter.setup_sessions
    env = {"java.servlet_request" => mock("servlet request")}
    @booter.set_session_options_for_request(env)
    env['rails.session_options'].should have_key(:java_servlet_request)
    env['rails.session_options'][:java_servlet_request].should == env["java.servlet_request"]
  end

  it "should set the PUBLIC_ROOT constant to the location of the public root" do
    create_booter(JRuby::Rack::RailsBooter).boot!
    PUBLIC_ROOT.should == @booter.public_path
  end

  describe "Rails 2 environment" do
    before :all do
      mock_servlet_context
      $servlet_context = @servlet_context
      @rack_context.should_receive(:getContextPath).and_return "/foo"
      create_booter(JRuby::Rack::RailsBooter) do |b|
        b.app_path = File.expand_path("../../../rails", __FILE__)
      end.boot!
      @booter.load_environment
    end

    after :all do
      $servlet_context = nil
    end

    it "should default the page cache directory to the public root" do
      ActionController::Base.page_cache_directory.should == @booter.public_path
    end

    it "should default the session store to the java servlet session store" do
      ActionController::Base.session_store.should == CGI::Session::JavaServletStore
    end

    it "should set the ActionView ASSETS_DIR constant to the public root" do
      ActionView::Helpers::AssetTagHelper::ASSETS_DIR.should == @booter.public_path
    end

    it "should set the ActionView JAVASCRIPTS_DIR constant to the public root/javascripts" do
      ActionView::Helpers::AssetTagHelper::JAVASCRIPTS_DIR.should == @booter.public_path + "/javascripts"
    end

    it "should set the ActionView STYLESHEETS_DIR constant to the public root/stylesheets" do
      ActionView::Helpers::AssetTagHelper::STYLESHEETS_DIR.should == @booter.public_path + "/stylesheets"
    end

    it "should set the ActionController.relative_url_root to the servlet context path" do
      ActionController::Base.relative_url_root.should == "/foo"
    end
  end

  describe "Rails 3.0 environment" do
    before :all do
      mock_servlet_context
      $servlet_context = @servlet_context
      create_booter(JRuby::Rack::RailsBooter) do |b|
        b.app_path = File.expand_path("../../../rails3", __FILE__)
      end.boot!
      @booter.load_environment
    end

    after :all do
      $servlet_context = nil
    end

    it "should set the application configuration's public path" do
      paths = {}
      %w(public public/javascripts public/stylesheets).each {|p| paths[p] = [p] }
      app = mock "app"
      public_path = Pathname.new(@booter.public_path)
      app.stub_chain(:config, :paths).and_return(paths)
      init = Rails::Railtie.initializers.detect {|i| i.first =~ /public_path/}
      init.should_not be_nil
      init[1].should == [{:before => "action_controller.set_configs"}]
      init.last.call(app)
      paths['public'].should == public_path.to_s
      paths['public/javascripts'].should == public_path.join("javascripts").to_s
      paths['public/stylesheets'].should == public_path.join("stylesheets").to_s
    end

    it "should switch out the logging device" do
      logger = mock "logger"
      class << logger; attr_accessor :log; end
      dev = mock "logdev"
      dev.should_receive(:close)
      logger.log = dev
      Rails.stub!(:logger).and_return(logger)
      init = Rails::Railtie.initializers.detect {|i| i.first =~ /log/}
      init.should_not be_nil
      init[1].should == [{:after => :initialize_logger}]
      init.last.call(nil)
      logger.log.should be_instance_of(JRuby::Rack::ServletLog)
    end

    it "should return the Rails.application instance" do
      app = mock "app"
      Rails.application = app
      @booter.to_app.should == app
    end

    it "should set config.action_controller.relative_url_root based on ENV['RAILS_RELATIVE_URL_ROOT']" do
      ENV['RAILS_RELATIVE_URL_ROOT'] = '/blah'
      app = mock "app"
      app.stub_chain(:config, :action_controller, :relative_url_root)
      app.config.action_controller.should_receive(:relative_url_root=).with("/blah")
      init = Rails::Railtie.initializers.detect {|i| i.first =~ /url/}
      init.should_not be_nil
      init[1].should == [{:after => "action_controller.set_configs"}]
      init.last.call(app)
    end
  end

  describe "Rails 3.1 environment" do
    before :all do
      mock_servlet_context
      $servlet_context = @servlet_context
      create_booter(JRuby::Rack::RailsBooter) do |b|
        b.app_path = File.expand_path("../../../rails3", __FILE__)
      end.boot!
      @booter.load_environment
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
      app = mock "app"
      app.stub_chain(:config, :action_controller, :respond_to?)
      app.config.action_controller.should_receive(:respond_to?).with(:relative_url_root=).and_return(false)
      app.config.action_controller.should_not_receive(:relative_url_root=)

      init = Rails::Railtie.initializers.detect {|i| i.first =~ /url/}
      init.should_not be_nil
      init[1].should == [{:after => "action_controller.set_configs"}]
      init.last.call(app)
    end
  end
end

describe JRuby::Rack, "Rails controller extensions" do
  before :each do
    @controller = ActionController::Base.new
    @controller.stub!(:request).and_return(request = mock("request"))
    @controller.stub!(:response).and_return(response = mock("response"))
    request.stub!(:env).and_return({"java.servlet_request" => (@servlet_request = mock("servlet request"))})
    @headers = {}
    response.stub!(:headers).and_return @headers
  end

  it "should add a #servlet_request method to ActionController::Base" do
    @controller.should respond_to(:servlet_request)
    @controller.servlet_request.should == @servlet_request
  end

  it "should add a #forward_to method for forwarding to another servlet" do
    @servlet_response = mock "servlet response"
    @controller.request.should_receive(:forward_to).with("/forward.jsp")

    @controller.forward_to "/forward.jsp"
  end
end
