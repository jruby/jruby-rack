require 'merb/rack/servlet_helper'
require 'merb/rack/servlet'
require 'merb/rack/servlet_session'
require 'merb/rack/servlet_setup'

helper = Merb::Rack::ServletHelper.instance

helper.load_merb

helper.logger.debug('Registering Merb servlet adapter')
Merb::Rack::Adapter.register %w{servlet}, :Servlet

helper.logger.debug('Registering Merb servlet sessions')      
Merb.register_session_type 'servlet', 
  'merb/rack/servlet_session', 
  'Using Java servlet sessions'    

config = {}
config[:merb_root] = helper.merb_root if helper.merb_root
config[:environment] = helper.merb_environment if helper.merb_environment
config[:adapter] = 'servlet'

helper.logger.debug('Starting Merb')
Merb.start(config)
