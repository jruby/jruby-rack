require 'sinatra'
helpers DemoHelpers

get '/' do
  "Oops! Something's not right.<br/>\nYou should be seeing <a href='index.html'>index.html</a> instead."
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
  result = erb :env
  write_environment(result)
  result
end
