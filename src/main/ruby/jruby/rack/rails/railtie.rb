require 'rails/railtie'

module JRuby::Rack
  class Railtie < ::Rails::Railtie
    railtie_name :jruby_rack

    initializer "set_webapp_public_path", :before => "action_controller.set_configs" do |app|
      app.config.paths.public = JRuby::Rack.booter.public_path
    end

    initializer "set_servlet_logger", :after => :initialize_logger do
      class << config.logger # Make these accessible to wire in the log device
        public :instance_variable_get, :instance_variable_set
      end
      old_device = config.logger.instance_variable_get "@log"
      old_device.close rescue nil
      config.logger.instance_variable_set "@log", JRuby::Rack.booter.logdev
    end

    initializer "set_relative_url_root", :after => "action_controller.set_configs" do
      path = JRuby::Rack.booter.rack_context.getContextPath
      if path && !path.empty?
        ENV['RAILS_RELATIVE_URL_ROOT'] = path
        config.action_controller.relative_url_root = path
      end
    end
  end
end
