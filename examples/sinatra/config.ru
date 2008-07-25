$:.unshift './vendor/sinatra/lib'
$:.unshift './lib'

require 'sinatra'
Sinatra::Application.default_options.merge!(
:run => false,
:env => :production,
:public => PUBLIC_ROOT
)

require 'demo'
run Sinatra.application
