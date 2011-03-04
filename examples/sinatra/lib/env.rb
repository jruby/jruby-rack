require 'sinatra'
if defined?(JRuby::Rack::Capture)
  helpers do
    include JRuby::Rack::Capture::Base
    include JRuby::Rack::Capture::RubyGems
    include JRuby::Rack::Capture::Bundler
    include JRuby::Rack::Capture::JRubyRackConfig
    include JRuby::Rack::Capture::Environment
    include JRuby::Rack::Capture::JavaEnvironment
    include JRuby::Rack::Capture::LoadPath
    include DemoCaptureHelper
    include FileStoreHelper
  end
else
  helpers DemoDummyHelper
end

get '/' do
  erb :root
end

post '/body' do
  res = "Content-Type was: #{request.content_type.inspect}\n"
  body = request.body.read
  if body.empty?
    status 400
    res << "Post body empty\n"
  else
    res << "Post body was:\n#{body}\n"
  end
end

get %r'.*/info' do
  content_type 'text/plain; charset=utf-8'
  erb :info
end

get '/env' do
  content_type 'text/plain; charset=utf-8'
  capture
  store
  output.string
end
