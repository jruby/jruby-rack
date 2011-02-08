# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  if ENV['JRUBY_RACK_SRC']
    config.java_libs.delete_if {|f| f =~ /jruby-rack[^\/]+\.jar/}
    config.java_libs += FileList["../../target/jruby-rack*.jar"]
  end
  config.dirs += ['views']
  require 'socket'
  config.webxml.ENV_OUTPUT = File.expand_path('../../servers', __FILE__)
  config.webxml.ENV_HOST   = Socket.gethostname
end
