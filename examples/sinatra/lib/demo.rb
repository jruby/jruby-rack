require 'sinatra'

get '/' do
  'Hello world!'
end

post '/' do
  res = "Content-Type was: #{request.content_type.inspect}\n"
  body = request.body.read
  if body.empty?
    status 400
    res << "Post body empty\n"
  else
    res << "Post body was:\n#{body}\n"
  end
end
