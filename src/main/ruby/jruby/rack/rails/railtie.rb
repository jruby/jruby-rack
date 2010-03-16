require 'rails/railtie'

module JRuby::Rack
  class Railtie < ::Rails::Railtie
    railtie_name :jruby_rack

    initializer "set_webapp_public_path", :before => "action_controller.set_configs" do |app|
      app.config.paths.public = JRuby::Rack.booter.public_path
    end
  end
end
