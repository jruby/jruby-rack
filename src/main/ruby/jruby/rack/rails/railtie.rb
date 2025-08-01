#--
# Copyright (c) 2012-2016 Karol Bucek, LTD.
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'active_support'
require 'rails/railtie'
require 'pathname'

module JRuby::Rack
  class Railtie < ::Rails::Railtie

    config.before_configuration do |app|
      public = JRuby::Rack.public_path
      if public # nil if /public does not exist
        paths = app.config.paths
        old_public  = Pathname.new(paths['public'].to_a.first)
        javascripts = Pathname.new(paths['public/javascripts'].to_a.first)
        stylesheets = Pathname.new(paths['public/stylesheets'].to_a.first)
        paths['public'] = public.to_s; public = Pathname.new(public)
        paths['public/javascripts'] = public.join(javascripts.relative_path_from(old_public)).to_s
        paths['public/stylesheets'] = public.join(stylesheets.relative_path_from(old_public)).to_s
      end
    end

    # TODO prefix initializers with 'jruby_rack.' !?

    initializer 'set_servlet_logger', :before => :initialize_logger do |app|
      app.config.logger ||= begin
        logger = JRuby::Rack.logger
        config = app.config
        log_level = config.log_level || :info
        logger.level = logger.class.const_get(log_level.to_s.upcase)
        log_formatter = config.log_formatter if config.respond_to?(:log_formatter)
        logger.formatter = log_formatter if log_formatter && logger.respond_to?(:formatter=)
        require 'active_support/tagged_logging' unless defined?(ActiveSupport::TaggedLogging)
        logger = ActiveSupport::TaggedLogging.new(logger) # returns a logger.clone
        logger.singleton_class.instance_eval do
          include ActiveSupport::LoggerSilence if defined?(ActiveSupport::LoggerSilence)
        end
        logger
      end
    end

    initializer 'set_relative_url_root', :after => 'action_controller.set_configs' do |app|
      # NOTE: this is most likely handled by Rails 3.x itself :
      # - *config.relative_url_root* since 3.2 defaults to _RAILS_RELATIVE_URL_ROOT_
      # - *config.action_controller.relative_url_root* is set from *config.relative_url_root*
      # - when a *config.relative_url_root* is set we should not interfere ...
      if ( env_url_root = ENV['RAILS_RELATIVE_URL_ROOT'] ) &&
        !( app.config.respond_to?(:relative_url_root) && app.config.relative_url_root )
        if action_controller = app.config.action_controller
          action_controller.relative_url_root = env_url_root
        elsif defined?(ActionController::Base) &&
          ActionController::Base.respond_to?(:relative_url_root=)
          # setting the config affects *ActionController::Base.relative_url_root*
          ActionController::Base.config.relative_url_root = env_url_root
        end
      end
    end

    initializer 'action_dispatch.autoload_java_servlet_store', :after => 'action_dispatch.configure' do
      # if it's loaded up front with a require 'action_controller'/'action_dispatch' then
      # it might fire up before 'active_record' has been required causing sweeping issues
      # @see https://github.com/jruby/jruby-rack/issues/42
      # loading it after the environment boots is too late as it might be set in a user
      # config/initializer: MyApp::Application.config.session_store :java_servlet_store
      ActionDispatch::Session.autoload :JavaServletStore, "action_dispatch/session/java_servlet_store"
    end

  end
end
