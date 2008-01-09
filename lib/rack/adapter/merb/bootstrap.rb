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

options[:merb_root] = servlet_helper.merb_root if servlet_helper.merb_root
options[:environment] = servlet_helper.merb_env if servlet_helper.merb_env
options[:path_prefix] = servlet_helper.path_prefix if servlet_helper.path_prefix
options[:session_store] = servlet_helper.session_store if servlet_helper.session_store

if options[:environment].to_s == 'production'
  options[:exception_details] = options.fetch(:exception_details, false)
  options[:cache_templates] = true
else
  options[:exception_details] = options.fetch(:exception_details, true)
end

Merb::Server.send :class_variable_set, :@@merb_opts, options
puts Merb::Server.instance_methods(false)
Merb::Server.register_session_type('java', 'rack/adapter/merb/java_session', 'Using Java Servlet sessions')
Merb::Server.initialize_merb
Object.const_set('MERB_LOGGER', servlet_helper.logger)

require 'rack/adapter/merb/factory'