require 'rubygems'
# Demo app built for 0.9.x
gem 'sinatra', '~> 0.9' 
require './lib/demo'
set :run, false
set :environment, :production
run Sinatra::Application
