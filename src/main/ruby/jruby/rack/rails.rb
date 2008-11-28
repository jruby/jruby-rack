#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
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
        @rails_root = expand_root_path @rails_root
        @rails_env = @servlet_context.getInitParameter 'rails.env'
        @rails_env ||= 'production'
        ENV['RAILS_ROOT'] = @rails_root
        ENV['RAILS_ENV'] = @rails_env
        silence_warnings { Object.const_set("PUBLIC_ROOT", public_root) }
      end

      def load_environment
        require 'cgi/session/java_servlet_store'
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
      def boot_for_servlet_environment(initializer)
        initializer_class = initializer.class
        initializer_class.module_eval do
          alias_method :require_frameworks_without_servlet_env, :require_frameworks
          def require_frameworks_with_servlet_env
            JRuby::Rack::RailsServletHelper.instance.before_require_frameworks
            require_frameworks_without_servlet_env
            JRuby::Rack::RailsServletHelper.instance.setup_actionpack
          end
          alias_method :require_frameworks, :require_frameworks_with_servlet_env
        end
      end

      def before_require_frameworks
        Rails.public_path = PUBLIC_ROOT if defined?(Rails.public_path)
      end

      def setup_actionpack
        ActionController::Base.session_store = :java_servlet_store
        unless defined?(Rails.public_path)
          ActionController::Base.page_cache_directory = PUBLIC_ROOT
          silence_warnings do
            asset_tag_helper = ActionView::Helpers::AssetTagHelper
            asset_tag_helper.const_set("ASSETS_DIR", PUBLIC_ROOT)
            asset_tag_helper.const_set("JAVASCRIPTS_DIR", "#{PUBLIC_ROOT}/javascripts")
            asset_tag_helper.const_set("STYLESHEETS_DIR", "#{PUBLIC_ROOT}/stylesheets")
          end
        end
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

          # use config.logger?
          if defined?(ActiveSupport::BufferedLogger) # Rails 2.x
            old_device = ::RAILS_DEFAULT_LOGGER.instance_variable_get "@log"
            old_device.close rescue nil
            ::RAILS_DEFAULT_LOGGER.instance_variable_set "@log", logdev
          else # Rails 1.x
            old_device = ::RAILS_DEFAULT_LOGGER.instance_variable_get "@logdev"
            old_device.close rescue nil
            ::RAILS_DEFAULT_LOGGER.instance_variable_set "@logdev", Logger::LogDevice.new(logdev)
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
    Bootstrap = RailsServletHelper

    class RailsSetup
      def initialize(app, servlet_helper)
        @app = app
        @servlet_helper = servlet_helper
      end

      def call(env)
        env['rails.session_options'] = @servlet_helper.session_options_for_request(env)
        env['HTTPS'] = 'on' if env['rack.url_scheme'] == 'https'
        relative_url_root = env['java.servlet_request'].getContextPath
        if relative_url_root && !relative_url_root.empty?
          env['RAILS_RELATIVE_URL_ROOT'] = relative_url_root
          ActionController::Base.relative_url_root = relative_url_root if ActionController::Base.respond_to?(:relative_url_root=)
        end
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
