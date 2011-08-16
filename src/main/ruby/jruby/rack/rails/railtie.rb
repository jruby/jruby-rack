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

    initializer "set_servlet_logger", :after => :initialize_logger do |app|
      class << Rails.logger # Make these accessible to wire in the log device
        public :instance_variable_get, :instance_variable_set
      end
      old_device = Rails.logger.instance_variable_get "@log"
      old_device.close rescue nil
      Rails.logger.instance_variable_set "@log", JRuby::Rack.booter.logdev
    end

    initializer "set_relative_url_root", :after => "action_controller.set_configs" do |app|
      if ENV['RAILS_RELATIVE_URL_ROOT']
        app.config.action_controller.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
        ActionController::Base.config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
      end
    end
  end
end
