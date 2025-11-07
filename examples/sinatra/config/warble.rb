# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  config.features += ['executable']

  config.dirs += ['views']
  require 'socket'
  config.webxml.ENV_OUTPUT = File.expand_path('../../servers', __FILE__)
  config.webxml.ENV_HOST   = Socket.gethostname
end
