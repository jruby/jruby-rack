require 'rack/adapter/merb/servlet_helper'

servlet_helper = Rack::Adapter::MerbServletHelper.instance

load File.join(servlet_helper.merb_root, 'config', 'boot.rb')

merb_yml = File.join(servlet_helper.merb_root, 'config', 'merb.yml')
options = if File.exists?(merb_yml)
            require 'merb/erubis_ext'
            Merb::Config.defaults.merge(Erubis.load_yaml_file(merb_yml))
          else
            Merb::Config.defaults
          end

options[:merb_root] = servlet_helper.merb_root
options[:merb_env] = servlet_helper.merb_env
if options[:environment].to_s == 'production'
  options[:exception_details] = options.fetch(:exception_details, false)
  options[:cache_templates] = true
else
  options[:exception_details] = options.fetch(:exception_details, true)
end
options[:path_prefix] = servlet_helper.path_prefix

Merb::Server.send :class_variable_set, :@@merb_opts, options
Merb::Server.initialize_merb
Object.const_set('MERB_LOGGER', servlet_helper.logger)

require 'rack/adapter/merb/factory'