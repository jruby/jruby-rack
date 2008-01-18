require 'rack/adapter/merb/servlet_helper'

servlet_helper = Rack::Adapter::MerbServletHelper.instance

load File.join(servlet_helper.merb_root, 'config', 'boot.rb')
Merb::Config.setup(File.join(servlet_helper.merb_root, 'config', 'merb.yml'))
Merb::Config[:merb_root] = servlet_helper.merb_root if servlet_helper.merb_root
Merb::Config[:environment] = servlet_helper.merb_env if servlet_helper.merb_env
Merb::Config[:path_prefix] = servlet_helper.path_prefix if servlet_helper.path_prefix
Merb::Config[:session_store] = servlet_helper.session_store if servlet_helper.session_store
Merb::BootLoader.register_session_type('java', 'rack/adapter/merb/java_session', 'Using Java Servlet sessions')
Merb::BootLoader.initialize_merb
Merb.logger = servlet_helper.logger

require 'rack/adapter/merb/factory'