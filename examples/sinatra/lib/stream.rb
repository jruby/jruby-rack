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
