require 'sinatra'
if EnvCaptureHelper.jruby_rack_capture_on?
  helpers do
    include JRuby::Rack::Capture::Base
    include JRuby::Rack::Capture::RubyGems
    include JRuby::Rack::Capture::Bundler
    include JRuby::Rack::Capture::JRubyRackConfig
    include JRuby::Rack::Capture::Environment
    include JRuby::Rack::Capture::JavaEnvironment
    include JRuby::Rack::Capture::LoadPath
    include EnvCaptureHelper
    include FileStoreHelper
  end
else
  helpers EnvDummyHelper
end

get '/' do
  erb :root
end

post '/body' do
  res = "Content-Type was: #{request.content_type.inspect}\n"
  request.body.rewind # Need to rewind to re-read body with Rack 3 - and rewindable bodies are not mandatory...
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

get '/jsp_forward' do
  request.forward_to "/jsp/index.jsp", {"message" => "Hello from JSP"}
end

get '/jsp_include' do
  erb :jsp_include
end
