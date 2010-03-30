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

get %r'.*/info' do
  env = request.env
  res = ""
  res << "rack.version: " << env["rack.version"].inspect << "\n"
  res << "CONTENT_TYPE: " << env["CONTENT_TYPE"].inspect << "\n"
  res << "HTTP_HOST: "    << env["HTTP_HOST"].inspect << "\n"
  res << "HTTP_ACCEPT: "  << env["HTTP_ACCEPT"].inspect << "\n"
  res << "REQUEST_METHOD: " << env["REQUEST_METHOD"].inspect << "\n"
  res << "SCRIPT_NAME: " << env["SCRIPT_NAME"].inspect << "\n"
  res << "PATH_INFO: " << env["PATH_INFO"].inspect << "\n"
  if env['java.servlet_request']
    res << "getServletPath: " << env['java.servlet_request'].getServletPath.inspect << "\n"
    res << "getPathInfo: " << env['java.servlet_request'].getPathInfo.inspect << "\n"
  end
  res << "REQUEST_URI: " << env["REQUEST_URI"].inspect << "\n"
  res << "QUERY_STRING: " << env["QUERY_STRING"].inspect << "\n"
  res << "SERVER_NAME: " << env["SERVER_NAME"].inspect << "\n"
  res << "SERVER_PORT: " << env["SERVER_PORT"].inspect << "\n"
  res << "REMOTE_HOST: " << env["REMOTE_HOST"].inspect << "\n"
  res << "REMOTE_ADDR: " << env["REMOTE_ADDR"].inspect << "\n"
  res << "REMOTE_USER: " << env["REMOTE_USER"].inspect << "\n"
  res
end
