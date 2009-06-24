#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

class JRuby::Rack::Response
  include Java::org.jruby.rack.RackResponse

  def initialize(arr)
    @status, @headers, @body = *arr
  end

  def getStatus
    @status
  end

  def getHeaders
    @headers
  end

  def getBody
    b = ""
    @body.each {|part| b << part }
    b
  end

  def respond(response)
    if (fwd = @headers["Forward"]) && fwd.respond_to?(:call)
      fwd.call(response)
    else
      write_status(response)
      write_headers(response)
      write_body(response)
    end
  end

  def write_status(response)
    response.setStatus(@status.to_i)
  end

  def write_headers(response)
    @headers.each do |k,v|
      case k
      when /^Content-Type$/i
        response.setContentType(v.to_s)
      when /^Content-Length$/i
        response.setContentLength(v.to_i)
      else
        if v.respond_to?(:each_line)
          v.each_line {|val| response.addHeader(k.to_s, val.chomp("\n")) }
        elsif v.respond_to?(:each)
          v.each {|val| response.addHeader(k.to_s, val.chomp("\n")) }
        else
          case v
          when Numeric
            response.addIntHeader(k.to_s, v.to_i)
          when Time
            response.addDateHeader(k.to_s, v.to_i * 1000)
          else
            response.addHeader(k.to_s, v.to_s)
          end
        end
      end
    end
  end

  def write_body(response)
    stream = response.getOutputStream
    begin
      @body.each do |el|
        stream.write(el.to_java_bytes)
      end
    rescue LocalJumpError => e
      # HACK: deal with objects that don't comply with Rack specification
      @body = [@body.to_s]
      retry
    end
  end
end
