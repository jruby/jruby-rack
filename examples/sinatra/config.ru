# -*- mode: ruby -*-

require './lib/helpers'
require 'bundler'
Bundler.setup
require './lib/env'
require './lib/stream'

set :run, false
set :public_folder, './public'
set :views, './views'
set :environment, :production
run Sinatra::Application
