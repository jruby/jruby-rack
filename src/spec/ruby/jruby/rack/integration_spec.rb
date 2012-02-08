
require 'spec_helper'
require 'fileutils'

import org.jruby.rack.RackContext
import org.jruby.rack.servlet.ServletRackContext
import org.jruby.rack.RackApplication
import org.jruby.rack.DefaultRackApplication
import org.jruby.rack.RackApplicationFactory
import org.jruby.rack.DefaultRackApplicationFactory
import org.jruby.rack.SharedRackApplicationFactory
import org.jruby.rack.PoolingRackApplicationFactory
import org.jruby.rack.rails.RailsRackApplicationFactory

describe "integration" do
  
  describe 'rack (lambda)' do
    
    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new "file://#{STUB_DIR}/rack"
      @servlet_context.logger = raise_logger
      #@servlet_context.logger = org.jruby.rack.logging.StandardOutLogger.new("")
    end
    
    it "initializes" do
      @servlet_context.addInitParameter('rackup', 
          "run lambda { |env| [200, {'Content-Type' => 'text/plain'}, 'OK'] }"
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
        servlet.getContext.should_not be_nil
        servlet.getDispatcher.should_not be_nil
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
        
        response.getStatus.should == 200
        response.getContentType == 'text/plain'
        response.getContentAsString.should == 'OK'
        response.getHeader("Via").should == 'JRuby-Rack'
      end
      
    end
    
  end

  shared_examples_for 'a rails app', :shared => true do
    
    it "initializes (pooling by default)" do
      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)

      rack_factory = @servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(PoolingRackApplicationFactory)
      rack_factory.should respond_to(:realFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)

      @servlet_context.getAttribute("rack.context").should be_a(RackContext)
      @servlet_context.getAttribute("rack.context").should be_a(ServletRackContext)
      
      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end

    it "initializes threadsafe!" do
      @servlet_context.addInitParameter('jruby.max.runtimes', '1')

      listener = org.jruby.rack.rails.RailsServletContextListener.new
      listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)

      rack_factory = @servlet_context.getAttribute("rack.factory")
      rack_factory.should be_a(RackApplicationFactory)
      rack_factory.should be_a(SharedRackApplicationFactory)
      rack_factory.realFactory.should be_a(RailsRackApplicationFactory)
      
      rack_factory.getApplication.should be_a(DefaultRackApplication)
    end
    
  end
  
  describe 'rails 3.0', :lib => :rails30 do
    
    before(:all) { copy_gemfile("rails30") }
    
    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new "file://#{STUB_DIR}/rails30"
      @servlet_context.logger = raise_logger
    end
    
    it_should_behave_like 'a rails app'
 
    context "initialized" do
      
      before :each do
        initialize_rails
      end
      
      it "loaded rack ~> 1.2" do
        @runtime = @rack_factory.getApplication.getRuntime
        should_eval_as_not_nil "defined?(Rack.release)"
        should_eval_as_eql_to "Rack.release.to_s[0, 3]", '1.2'
      end
      
    end

    context "initialized (custom)" do

      before :each do
        @servlet_context.addInitParameter("rails.env", 'custom')
        initialize_rails
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
    
    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new "file://#{STUB_DIR}/rails31"
      @servlet_context.logger = raise_logger
    end
    
    it_should_behave_like 'a rails app'
    
    context "initialized" do
      
      before :each do
        initialize_rails
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
      
    end
    
  end
  
  describe 'rails 3.2', :lib => :rails32 do
    
    before(:all) { copy_gemfile("rails32") }
    
    before do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new "file://#{STUB_DIR}/rails32"
      @servlet_context.logger = raise_logger
    end
    
    it_should_behave_like 'a rails app'
    
    context "initialized" do
      
      before :each do
        initialize_rails
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
      
    end
    
  end
  
  def initialize_rails
    listener = org.jruby.rack.rails.RailsServletContextListener.new
    listener.contextInitialized javax.servlet.ServletContextEvent.new(@servlet_context)
    @rack_context = @servlet_context.getAttribute("rack.context")
    @rack_factory = @servlet_context.getAttribute("rack.factory")
  end
  
  private
  
    GEMFILES_DIR = File.expand_path('../../../gemfiles', STUB_DIR)
  
    def copy_gemfile(name) # e.g. 'rails30'
      FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile")
      FileUtils.cp File.join(GEMFILES_DIR, "#{name}.gemfile.lock"), File.join(STUB_DIR, "#{name}/WEB-INF/Gemfile.lock")
    end
  
end
