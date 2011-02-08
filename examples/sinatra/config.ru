# -*- mode: ruby -*-

require './lib/helpers'
extend DemoHelpers
begin
  pre_capture_paths
  require 'bundler/setup'
  post_capture_paths
  require './lib/demo'
rescue Exception => e
  write_environment(nil, e) rescue nil
  raise e
end

set :run, false
set :public, './public'
set :views, './views'
set :environment, :production
run Sinatra::Application
