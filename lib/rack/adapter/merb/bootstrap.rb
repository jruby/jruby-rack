require 'rack/adapter/merb/servlet_helper'

merb_env = Rack::Adapter::MerbServletHelper.instance.merb_env
merb_root = Rack::Adapter::MerbServletHelper.instance.merb_root

require 'rubygems'
Gem.clear_paths
Gem.path.unshift(File.join(merb_root, 'gems'))

load File.join(merb_root, 'config', 'boot.rb')

merb_yml = File.join(merb_root, 'config', 'merb.yml')
options = if File.exists?(merb_yml)
            require 'merb/erubis_ext'
            Merb::Config.defaults.merge(Erubis.load_yaml_file(merb_yml))
          else
            Merb::Config.defaults
          end
options[:merb_root] = merb_root
options[:merb_env] = merb_env
if options[:environment].to_s == 'production'
  options[:exception_details] = options.fetch(:exception_details, false)
  options[:cache_templates] = true
else
  options[:exception_details] = options.fetch(:exception_details, true)
end
Merb::Server.send :class_variable_set, :@@merb_opts, options
Merb::Server.initialize_merb

require 'rack/adapter/merb/factory'