#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rails/railtie'
require 'pathname'

module JRuby::Rack
  class Railtie < ::Rails::Railtie
    initializer "set_webapp_public_path", :before => "action_controller.set_configs" do |app|
      paths = app.config.paths
      if Hash === paths
        # Rails 3.1: paths["app/controllers"] style
        old_public  = Pathname.new(paths['public'].to_a.first)
        new_public  = Pathname.new(JRuby::Rack.booter.public_path)
        javascripts = Pathname.new(paths['public/javascripts'].to_a.first)
        stylesheets = Pathname.new(paths['public/stylesheets'].to_a.first)
        paths['public'] = new_public.to_s
        paths['public/javascripts'] = new_public.join(javascripts.relative_path_from(old_public)).to_s
        paths['public/stylesheets'] = new_public.join(stylesheets.relative_path_from(old_public)).to_s
      else
        # Rails 3.0: old paths.app.controllers style
        old_public  = Pathname.new(paths.public.to_a.first)
        new_public  = Pathname.new(JRuby::Rack.booter.public_path)
        javascripts = Pathname.new(paths.public.javascripts.to_a.first)
        stylesheets = Pathname.new(paths.public.stylesheets.to_a.first)
        paths.public = new_public.to_s
        paths.public.javascripts = new_public.join(javascripts.relative_path_from(old_public)).to_s
        paths.public.stylesheets = new_public.join(stylesheets.relative_path_from(old_public)).to_s
      end
    end

    initializer "set_servlet_logger", :before => :initialize_logger do |app|
      app.config.logger = JRuby::Rack.booter.logger
    end

    initializer "set_relative_url_root", :after => "action_controller.set_configs" do |app|
      if ENV['RAILS_RELATIVE_URL_ROOT']
        app.config.action_controller.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT'] if app.config.action_controller.respond_to?(:relative_url_root=)
        ActionController::Base.config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT'] if ActionController::Base.config.respond_to?(:relative_url_root=)
      end
    end

    initializer "action_dispatch.autoload_java_servlet_store", :after => "action_dispatch.configure" do
      # if it's loaded up front with a require 'action_controller'/'action_dispatch' then
      # it might fire up before 'active_record' has been required causing sweeping issues
      # @see https://github.com/jruby/jruby-rack/issues/42
      # loading it after the environment boots is too late as it might be set in a user
      # config/initializer: MyApp::Application.config.session_store :java_servlet_store
      ActionDispatch::Session.module_eval do
        autoload :JavaServletStore, "action_dispatch/session/java_servlet_store"
      end
    end

  end
end
