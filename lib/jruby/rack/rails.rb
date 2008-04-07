#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'

module JRuby
  module Rack
    class RailsServletHelper < ServletHelper
      attr_accessor :rails_env, :rails_root

      def initialize(servlet_context = nil)
        super
        @rails_root = @servlet_context.getInitParameter 'rails.root'
        @rails_root ||= '/WEB-INF'
        @rails_root = @servlet_context.getRealPath @rails_root
        @rails_env = @servlet_context.getInitParameter 'rails.env'
        @rails_env ||= 'production'
        ENV['RAILS_ROOT'] = @rails_root
        ENV['RAILS_ENV'] = @rails_env
        old_verbose, $VERBOSE = $VERBOSE, nil
        Object.const_set("PUBLIC_ROOT", public_root)
        $VERBOSE = old_verbose
      end
      
      def load_environment
        require 'jruby/rack/rails_boot'
        load File.join(rails_root, 'config', 'environment.rb')
        require 'dispatcher'
        require 'jruby/rack/rails_ext'
        setup_sessions
        setup_logger
      end
      
      # This hook method is called back from within the mechanism installed
      # by rails_boot above. We're setting appropriate defaults for the
      # servlet environment here that can still be overridden (if desired) in
      # the application's environment files.
      def boot_for_servlet_environment
        require 'action_controller'
        require 'cgi/session/java_servlet_store'
        ActionController::Base.page_cache_directory = PUBLIC_ROOT
        ActionController::Base.session_store = :java_servlet_store
        ActionView::Base.cache_template_loading = true
      end

      def setup_sessions
        if default_sessions?
          session_options[:database_manager] = java_servlet_store
        end
        # Turn off default cookies when using Java sessions
        if java_sessions?
          session_options[:no_cookies] = true
        end
      end

      def setup_logger
        if defined?(::RAILS_DEFAULT_LOGGER)
          class << ::RAILS_DEFAULT_LOGGER # Make these accessible to wire in the log device
            public :instance_variable_get, :instance_variable_set
          end
          
          if defined?(ActiveSupport::BufferedLogger) # Rails 2.x
            old_device = ::RAILS_DEFAULT_LOGGER.instance_variable_get "@log"
            old_device.close rescue nil
            ::RAILS_DEFAULT_LOGGER.instance_variable_set "@log", logdev
          else # Rails 1.x
            old_device = ::RAILS_DEFAULT_LOGGER.instance_variable_get "@logdev"
            old_device.close rescue nil
            ::RAILS_DEFAULT_LOGGER.instance_variable_set "@logdev", Logger::LogDevice.new(device)
          end
        end
      end

      def session_options
        @session_options ||= SESSION_OPTIONS
      end

      def session_options_for_request(env)
        options = session_options.dup
        options[:java_servlet_request] = env['java.servlet_request']
        options
      end
      
      def java_sessions?
        session_options[:database_manager] == java_servlet_store
      end

      def default_sessions?
        session_options[:database_manager] == default_store
      end

      def default_store
        defined?(::CGI::Session::PStore) && CGI::Session::PStore
      end

      def java_servlet_store
        CGI::Session::JavaServletStore
      end

      def options
        {:public => public_root, :root => rails_root, :environment => rails_env}
      end
    end

    class RailsSetup
      def initialize(app, servlet_helper)
        @app = app
        @servlet_helper = servlet_helper
      end

      def call(env)
        env['rails.session_options'] = @servlet_helper.session_options_for_request(env)
        env["RAILS_RELATIVE_URL_ROOT"] = env['java.servlet_request'].getContextPath
        @app.call(env)
      end
    end

    class RailsFactory
      def self.new
        helper = RailsServletHelper.instance
        helper.load_environment
        ::Rack::Builder.new {
          use RailsSetup, helper
          run ::Rack::Adapter::Rails.new(helper.options)
        }.to_app
      end
    end
  end
end