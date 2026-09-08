get '/stream' do
  erb :stream
end

class MultipartBody
  def initialize(response, &block)
    @boundary = 'MultipartBody'
    response['Content-Type'] = "multipart/mixed; boundary=\"#{@boundary}\""
    response['Transfer-Encoding'] = 'chunked'
    instance_eval(&block) if block
  end

  def chunk(content_type, body)
    "--#{@boundary}\nContent-Type: #{content_type}\n\n#{body}\n"
  end
end

class ServerTime < MultipartBody
  def each
    loop do
      yield chunk("application/json", "{\"currentTime\":\"#{Time.now.strftime '%H:%M:%S'}\"}")
      sleep 2
    end
  end
end

get '/servertime' do
  ServerTime.new(response)
end

# Sanity check for JRuby-Rack's Rack 3 "streaming body" support: this route
# returns a body that responds to #call (and NOT #each), i.e. a Rack 3.x
# streaming body - unlike /servertime above which is an #each (enumerable) body.
# JRuby-Rack hands the body a `stream` wrapping the servlet output; each write
# is flushed, so chunks arrive one-per-second. Watch it with:
#   curl -N http://localhost:8080/<context>/stream_call
get '/stream_call' do
  streaming_body = lambda do |stream|
    5.times do |i|
      stream.write "chunk #{i} @ #{Time.now.strftime('%H:%M:%S')}\n"
      sleep 1
    end
  ensure
    stream.close
  end
  # return a raw Rack response tuple so Sinatra passes the #call body through
  halt 200, { 'content-type' => 'text/plain', 'x-accel-buffering' => 'no' }, streaming_body
end
