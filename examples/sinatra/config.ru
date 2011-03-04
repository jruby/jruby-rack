# -*- mode: ruby -*-

require './lib/helpers'
require 'rubygems'
require 'bundler/setup'
require './lib/env'
require './lib/stream'

set :run, false
set :public, './public'
set :views, './views'
set :environment, :production
run Sinatra::Application
