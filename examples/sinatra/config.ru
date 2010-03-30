require 'rubygems'
gem 'sinatra'
require './lib/demo'
set :run, false
set :environment, :production
run Sinatra::Application
