# encoding: UTF-8
#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/response'

describe JRuby::Rack::Response do
  
  before :each do
    @status, @headers, @body = mock("status"), mock("headers"), mock("body")
    @headers.stub!(:[]).and_return nil
    @servlet_response = mock "servlet response"
    @response = JRuby::Rack::Response.new([@status, @headers, @body])
  end

  it "should return the status, headers and body" do
    @response.getStatus.should == @status
    @response.getHeaders.should == @headers
    @body.should_receive(:each).and_yield "hello"
    @response.getBody.should == "hello"
  end

  it "should write the status to the servlet response" do
    @status.should_receive(:to_i).and_return(200)
    @servlet_response.should_receive(:setStatus).with(200)
    @response.write_status(@servlet_response)
  end

  it "should write the headers to the servlet response" do
    @headers.should_receive(:each). # @headers.each do |k, v|
      and_yield("Content-Type", "text/html").
      and_yield("Content-Length", "20").
      and_yield("Server",  "Apache/2.2.x")
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Server", "Apache/2.2.x")
    @response.write_headers(@servlet_response)
  end

  it "should write headers with multiple values multiple addHeader invocations" do
    @headers.should_receive(:each). # @headers.each do |k, v|
      and_yield("Content-Type", "text/html").
      and_yield("Content-Length", "20").
      and_yield("Set-Cookie",  %w(cookie1 cookie2))
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should write headers whose value contains newlines as multiple addHeader invocations" do
    @headers.should_receive(:each).
      and_yield("Set-Cookie",  "cookie1\ncookie2")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should write headers whose value contains newlines as multiple addHeader invocations when string doesn't respond to #each" do
    str = "cookie1\ncookie2"
    class << str; undef_method :each; end if str.respond_to?(:each)
    @headers.should_receive(:each).and_yield "Set-Cookie", str
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should call addIntHeader with integer value" do
    @headers.should_receive(:each).and_yield "Expires", 0
    @servlet_response.should_receive(:addIntHeader).with("Expires", 0)
    @response.write_headers(@servlet_response)
  end

  it "should call addDateHeader with date value" do
    time = Time.now - 1000
    @headers.should_receive(:each).and_yield "Last-Modified", time
    @servlet_response.should_receive(:addDateHeader).with("Last-Modified", time.to_i * 1000)
    @response.write_headers(@servlet_response)
  end

  it "should write the status first, followed by the headers, and the body last" do
    @servlet_response.should_receive(:committed?).and_return false
    @response.should_receive(:write_status).ordered
    @response.should_receive(:write_headers).ordered
    @response.should_receive(:write_body).ordered
    @response.respond(@servlet_response)
  end

  it "should not write the status, the headers, or the body if the request was forwarded" do
    @servlet_response.should_receive(:committed?).and_return true
    @response.should_not_receive(:write_status)
    @response.should_not_receive(:write_headers)
    @response.should_not_receive(:write_body)
    @response.respond(@servlet_response)
  end

  it "#getBody should call close on the body if the body responds to close" do
    @body.should_receive(:each).ordered.and_yield "hello"
    @body.should_receive(:close).ordered
    @response.getBody.should == "hello"
  end

  it "detects a chunked response when the Transfer-Encoding header is set" do
    @headers = { "Transfer-Encoding" => "chunked" }
    @response = JRuby::Rack::Response.new([@status, @headers, @body])
    # NOTE: servlet container auto handle chunking when flushed no need to set :
    @servlet_response.should_not_receive(:addHeader).with("Transfer-Encoding", "chunked")
    @response.write_headers(@servlet_response)
    @response.send(:chunked?).should be true
  end
  
  describe "#write_body" do
    
    let(:stream) do
      StubOutputStream.new.tap do |stream|
        @servlet_response.stub!(:getOutputStream).and_return stream
      end
    end
    
    it "writes the body to the stream and flushes when the response is chunked" do
      @headers = { "Transfer-Encoding" => "chunked" }
      @response = JRuby::Rack::Response.new([@status, @headers, @body])
      # NOTE: servlet container auto handle chunking when flushed no need to set :
      @servlet_response.should_not_receive(:addHeader).with("Transfer-Encoding", "chunked")
      @response.write_headers(@servlet_response)
      @response.send(:chunked?).should == true
      @body.should_receive(:each).ordered.and_yield("hello").and_yield("there")
      stream.should_receive(:write).exactly(2).times
      stream.should_receive(:flush).exactly(2).times
      @response.write_body(@servlet_response)
    end

    it "dechunks the body when a chunked response is detected", 
      :lib => [ :rails23, :rails31, :rails32, :rails40 ] do
      require 'rack/chunked'
      
      headers = { 
        "Cache-Control" => 'no-cache',
        "Transfer-Encoding" => 'chunked'
      }
      body = [
        "1".freeze,
        "\nsecond chunk",
        "a multi\nline chunk \n42",
        "utf-8 chunk 'ty píčo'!\n",
        "terminated chunk\r\n",
        "", # should be skipped
        "\r\nthe very\r\n last\r\n\r\n chunk"
      ]
      
      with_dechunk do
        if defined? Rack::Chunked::Body # Rails 3.x
          body = Rack::Chunked::Body.new body
          response = JRuby::Rack::Response.new([ 200, headers, body ])
        else # Rails 2.3 -> Rack 1.1
          chunked = Rack::Chunked.new nil # nil application
          response = JRuby::Rack::Response.new chunked.chunk(200, headers, body)
        end
        @servlet_response.stub!(:getOutputStream).and_return stream = mock("stream")
        @servlet_response.stub!(:addHeader)
        response.write_headers(@servlet_response)

        times = 0
        stream.should_receive(:write).exactly(6).times.with do |bytes|
          str = String.from_java_bytes(bytes)
          str = str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
          case times += 1
          when 1 then str.should == "1"
          when 2 then str.should == "\nsecond chunk"
          when 3 then str.should == "a multi\nline chunk \n42"
          when 4 then str.should == "utf-8 chunk 'ty píčo'!\n"
          when 5 then str.should == "terminated chunk\r\n"
          when 6 then str.should == "\r\nthe very\r\n last\r\n\r\n chunk"
          else
            fail("unexpected :write received with #{str.inspect}")
          end
        end
        stream.should_receive(:flush).exactly(6+1).times # +1 for tail chunk

        response.write_body(@servlet_response)
      end
    end
    
    it "does not dechunk body when dechunkins is turned off",
      :lib => [ :rails31, :rails32, :rails40 ] do
      dechunk = JRuby::Rack::Response.dechunk?
      begin
        JRuby::Rack::Response.dechunk = false
        
        require 'rack/chunked'
        headers = { 
          "Cache-Control" => 'no-cache',
          "Transfer-Encoding" => 'chunked'
        }
        body = [
          "1".freeze,
          "\nsecond chunk",
          ""
        ]
        body = Rack::Chunked::Body.new body
        response = JRuby::Rack::Response.new([ 200, headers, body ])
        @servlet_response.stub!(:getOutputStream).and_return stream = mock("stream")
        @servlet_response.stub!(:addHeader)
        response.write_headers(@servlet_response)

        times = 0
        stream.should_receive(:write).exactly(3).times.with do |bytes|
          str = String.from_java_bytes(bytes)
          case times += 1
          when 1 then str.should == "1\r\n1\r\n"
          when 2 then str.should == "d\r\n\nsecond chunk\r\n"
          when 3 then str.should == "0\r\n\r\n"
          else
            fail("unexpected :write received with #{str.inspect}")
          end
        end
        stream.should_receive(:flush).exactly(3).times
        response.write_body(@servlet_response)
        
      ensure
        JRuby::Rack::Response.dechunk = dechunk
      end
    end
    
    it "handles dechunking gracefully when body is not chunked" do
      headers = { 
        "Transfer-Encoding" => 'chunked'
      }
      body = [
        "1".freeze,
        "a multi\nline chunk \n42",
        "\r\nthe very\r\n last\r\n\r\n chunk",
        "7\r\nty píčo\r\n", # " incorrect bytesize (9)
        "21\r\n a chunk with an invalid length \r\n" # size == 32 (0x20)
      ]
      response = JRuby::Rack::Response.new([ 200, headers, body ])
      @servlet_response.stub!(:getOutputStream).and_return stream = mock("stream")
      @servlet_response.stub!(:addHeader)
      response.write_headers(@servlet_response)

      times = 0
      stream.should_receive(:write).exactly(5).times.with do |bytes|
        str = String.from_java_bytes(bytes)
        case times += 1
        when 1 then str.should == "1"
        when 2 then str.should == "a multi\nline chunk \n42"
        when 3 then str.should == "\r\nthe very\r\n last\r\n\r\n chunk"
        when 4 then 
          str = str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
          str.should == "7\r\nty píčo\r\n"
        when 5 then str.should == "21\r\n a chunk with an invalid length \r\n"
        else
          fail("unexpected :write received with #{str.inspect}")
        end
      end
      stream.should_receive(:flush).exactly(5).times
      
      response.write_body(@servlet_response)
    end
    
    it "flushed the body when no Content-Length set" do
      @response = JRuby::Rack::Response.new([ 200, {}, @body ])
      @servlet_response.stub!(:addHeader)
      @body.should_receive(:each).ordered.and_yield("hello").and_yield("there")
      @response.write_headers(@servlet_response)
      stream.should_receive(:write).once.ordered
      stream.should_receive(:flush).once.ordered
      stream.should_receive(:write).once.ordered
      stream.should_receive(:flush).once.ordered
      @response.write_body(@servlet_response)
    end

    it "does not flush the body when Content-Length set" do
      @headers = { "Content-Length" => 10 }
      @response = JRuby::Rack::Response.new([ 200, @headers, @body ])
      @servlet_response.stub!(:addHeader)
      @servlet_response.stub!(:setContentLength)
      @body.should_receive(:each).ordered.and_yield("hello").and_yield("there")
      @response.write_headers(@servlet_response)
      stream.should_receive(:write).twice
      stream.should_receive(:flush).never
      @response.write_body(@servlet_response)
    end
    
    it "writes the body to the servlet response" do
      @body.should_receive(:each).
        and_yield("hello").
        and_yield("there")

      stream.should_receive(:write).exactly(2).times

      @response.write_body(@servlet_response)
    end

    it "calls close on the body if the body responds to close" do
      @body.should_receive(:each).ordered.
        and_yield("hello").
        and_yield("there")
      @body.should_receive(:close).ordered
      stream.should_receive(:write).exactly(2).times

      @response.write_body(@servlet_response)
    end

    it "yields the stream to an object that responds to #call" do
      @body.should_receive(:call).and_return do |stream|
        stream.write("".to_java_bytes)
      end
      stream.should_receive(:write).exactly(1).times

      @response.write_body(@servlet_response)
    end

    it "does not yield the stream if the object responds to both #call and #each" do
      @body.stub!(:call)
      @body.should_receive(:each).and_yield("hi")
      stream.should_receive(:write)

      @response.write_body(@servlet_response)
    end

    it "writes the stream using a channel if the object responds to #to_channel " + 
       "(and closes the channel)" do
      channel = mock "channel"
      @body.should_receive(:to_channel).and_return channel
      read_done = false
      channel.should_receive(:read).exactly(2).times.and_return do |buf|
        if read_done
          -1
        else
          buf.put "hello".to_java_bytes
          read_done = true
          5
        end
      end
      channel.should_receive(:close)
      stream.should_receive(:write)

      @response.write_body(@servlet_response)
    end
    
    it "streams a file using a channel if wrapped in body_parts", 
      :lib => [ :rails30, :rails31, :rails32 ] do
      body = wrap_file_body path = 
        File.expand_path('../../files/image.jpg', File.dirname(__FILE__))
      
      response = JRuby::Rack::Response.new [ 200, body.headers, body ]
      stream = self.stream
      response.should_receive(:transfer_channel).with do |ch, s|
        s.should == stream 
        ch.should be_a java.nio.channels.FileChannel
        ch.size.should == File.size(path)
      end

      response.write_body(@servlet_response)
    end

    it "closes original body and during write_body", 
      :lib => [ :rails30, :rails31, :rails32 ] do
      body = wrap_file_body File.expand_path('../../files/image.jpg', File.dirname(__FILE__))
      
      response = JRuby::Rack::Response.new [ 200, body.headers, body ]
      stream = self.stream
      response.should_receive(:transfer_channel).with do |ch, s|
        ch.should_receive(:close)
      end

      body.should_receive(:close)
      response.write_body(@servlet_response)
    end
    
    def wrap_file_body(path) # Rails style when doing #send_file
      require 'action_dispatch/http/response'
      
      file = File.open(path, 'rb')
      headers = { 
        "Content-Disposition" => "attachment; filename=\"image.jpg\"", 
        "Content-Transfer-Encoding" => "binary", 
        "Content-Type" => "image/jpeg" 
      }
      # we're emulating the body how rails returns it (for a file response)
      body = ActionDispatch::Response.new(200, headers, file)
      body = Rack::BodyProxy.new(body) { nil } if defined?(Rack::BodyProxy)
      # Rack::BodyProxy not available with Rails 3.0.x
      # with 3.2 there's even more wrapping with ActionDispatch::BodyProxy
      body
    end
    
    it "uses #transfer_to to copy the stream if available" do
      channel = mock "channel"
      @body.should_receive(:to_channel).and_return channel
      chunk_size = JRuby::Rack::Response.channel_chunk_size
      channel.stub!(:size).and_return(chunk_size + 10); channel.stub!(:close)
      channel.should_receive(:transfer_to).ordered.with(0, chunk_size, anything).and_return(chunk_size)
      channel.should_receive(:transfer_to).ordered.with(chunk_size, chunk_size, anything).and_return(10)
      stream.should be_kind_of(java.io.OutputStream)

      @response.write_body(@servlet_response)
    end

    it "writes the stream using a channel if the object responds to #to_inputstream" do
      @body.should_receive(:to_inputstream).and_return StubInputStream.new("hello")
      stream.should be_kind_of(java.io.OutputStream)

      @response.write_body(@servlet_response)
      stream.to_s.should == "hello"
    end
    
    private
    
    def with_dechunk(dechunk = true)
      begin
        prev_dechunk = JRuby::Rack::Response.dechunk?
        JRuby::Rack::Response.dechunk = dechunk
        yield
      ensure
        JRuby::Rack::Response.dechunk = prev_dechunk
      end
    end
    
  end
  
end
