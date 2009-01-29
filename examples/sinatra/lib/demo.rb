require 'sinatra'

get '/' do
  'Hello world!'
end

post '/' do
  body = request.body.read
  if body.empty?
    status 400
    "Post body empty\n"
  else
    "Post body was:\n#{body}\n"
  end
end
