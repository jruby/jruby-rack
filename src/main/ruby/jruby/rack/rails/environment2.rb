#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/rails_booter'

# Rails 2.x (JRuby-Rack >= 1.1.0 only supports 2.3) specific booter behavior.
module JRuby::Rack::RailsBooter::Rails2Environment
  
  # @return [::Rack::Adapter::Rails] a Rack compatible Rails application wrapper
  def to_app
    # backward "compatibility" calling #to_app without a #load_environment
    load_environment unless @load_environment
    require 'rack/adapter/rails'
    rails_adapter = ::Rack::Adapter::Rails.new(:public => public_path, :root => app_path)
    rack_based_sessions? ? rails_adapter : RailsRequestSetup.new(rails_adapter, session_options)
  end

  # Loads the Rails 2.x environment.
  def load_environment
    require 'jruby/rack/rails/boot_hook'
    load File.join(app_path, 'config', 'environment.rb')
    require 'dispatcher'
    setup_sessions
    setup_logger
    setup_relative_url_root
    @load_environment = true # prevent 2x load 'environment.rb'
  end

  protected

  def set_public_root
    silence_warnings { Object.const_set(:PUBLIC_ROOT, public_path) }
  end
  
  public
  
  # This hook method is called back from within the mechanism installed
  # by rails_boot above. We're setting appropriate defaults for the
  # servlet environment here that can still be overridden (if desired) in
  # the application's environment files.
  def boot_for_servlet_environment(initializer)
    initializer_class = initializer.class
    initializer_class.module_eval do
      alias_method :require_frameworks_without_servlet_env, :require_frameworks
      def require_frameworks_with_servlet_env
        JRuby::Rack.booter.before_require_frameworks
        require_frameworks_without_servlet_env
        JRuby::Rack.booter.setup_actionpack
        require 'jruby/rack/rails/extensions2'
      end
      alias_method :require_frameworks, :require_frameworks_with_servlet_env
    end
  end

  def before_require_frameworks
    Rails.public_path = PUBLIC_ROOT if defined?(Rails.public_path)
  end

  def setup_actionpack
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

  def setup_relative_url_root
    if ENV['RAILS_RELATIVE_URL_ROOT'] && ActionController::Base.respond_to?(:relative_url_root=)
      ActionController::Base.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
    end
  end
  
  def rack_based_sessions?
    defined?(ActionController::Session::AbstractStore)
  end

  def setup_sessions
    unless rack_based_sessions?
      if pstore_sessions?
        require 'cgi/session/java_servlet_store'
        session_options[:database_manager] = CGI::Session::JavaServletStore
      end
      # Turn off default cookies when using Java sessions
      if java_sessions?
        session_options[:no_cookies] = true
      end
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
    @session_options ||= ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
  end

  def java_sessions?
    session_options[:database_manager].to_s =~ /JavaServletStore$/
  end

  def pstore_sessions?
    session_options[:database_manager] == (defined?(::CGI::Session::PStore) && ::CGI::Session::PStore)
  end
  
  class RailsRequestSetup # :nodoc only used for (non-rack based) CGI sessions
    
    def initialize(app, session_options)
      @app, @session_options = app, session_options
    end

    def call(env)
      options = @session_options.dup
      options[:java_servlet_request] = env['java.servlet_request']
      env['rails.session_options'] = options
      @app.call(env)
    end
    
  end

end