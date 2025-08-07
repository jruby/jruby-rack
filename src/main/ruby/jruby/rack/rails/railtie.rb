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
      paths = app.config.paths; public = JRuby::Rack.public_path
      if paths.respond_to?(:'[]') && paths.respond_to?(:keys)
        # Rails 3.1/3.2/4.x: paths["app/controllers"] style
        old_public  = Pathname.new(paths['public'].to_a.first)
        javascripts = Pathname.new(paths['public/javascripts'].to_a.first)
        stylesheets = Pathname.new(paths['public/stylesheets'].to_a.first)
        paths['public'] = public.to_s; public = Pathname.new(public)
        paths['public/javascripts'] = public.join(javascripts.relative_path_from(old_public)).to_s
        paths['public/stylesheets'] = public.join(stylesheets.relative_path_from(old_public)).to_s
      else
        # Rails 3.0: old paths.app.controllers style
        old_public  = Pathname.new(paths.public.to_a.first)
        javascripts = Pathname.new(paths.public.javascripts.to_a.first)
        stylesheets = Pathname.new(paths.public.stylesheets.to_a.first)
        paths.public = public.to_s; public = Pathname.new(public)
        paths.public.javascripts = public.join(javascripts.relative_path_from(old_public)).to_s
        paths.public.stylesheets = public.join(stylesheets.relative_path_from(old_public)).to_s
      end if public # nil if /public does not exist
    end

    # TODO prefix initializers with 'jruby_rack.' !?

    initializer 'set_servlet_logger', :before => :initialize_logger do |app|
      app.config.logger ||= begin
        config = app.config; logger = JRuby::Rack.logger
        log_level = config.log_level || :info
        logger.level = logger.class.const_get(log_level.to_s.upcase)
        log_formatter = config.log_formatter if config.respond_to?(:log_formatter) # >= 4.0
        logger.formatter = log_formatter if log_formatter && logger.respond_to?(:formatter=)
        if defined?(ActiveSupport::TaggedLogging)
          if ActiveSupport::TaggedLogging.is_a?(Class) # Rails 3.2
            logger = ActiveSupport::TaggedLogging.new(logger)
          else # Rails 4.0
            # extends the logger as well as it's logger.formatter instance :
            # NOTE: good idea to keep or should we use a clone as Rails.logger ?
            #dup_logger = logger.dup
            #dup_logger.formatter = logger.formatter.dup
            logger = ActiveSupport::TaggedLogging.new(logger)
          end
        end
        logger
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
