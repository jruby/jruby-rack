#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
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
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Server",  "Apache/2.2.x"
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Server", "Apache/2.2.x")
    @response.write_headers(@servlet_response)
  end

  it "should write headers with multiple values multiple addHeader invocations" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Set-Cookie",  %w(cookie1 cookie2)
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should write headers whose value contains newlines as multiple addHeader invocations" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Set-Cookie",  "cookie1\ncookie2"
    end
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should write headers whose value contains newlines as multiple addHeader invocations when string doesn't respond to #each" do
    @headers.should_receive(:each).and_return do |block|
      s = "cookie1\ncookie2"
      class << s; undef_method :each; end if s.respond_to?(:each)
      block.call "Set-Cookie", s
    end
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should call addIntHeader with integer value" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Expires", 0
    end
    @servlet_response.should_receive(:addIntHeader).with("Expires", 0)
    @response.write_headers(@servlet_response)
  end

  it "should call addDateHeader with date value" do
    time = Time.now - 1000
    @headers.should_receive(:each).and_return do |block|
      block.call "Last-Modified", time
    end
    @servlet_response.should_receive(:addDateHeader).with("Last-Modified", time.to_i * 1000)
    @response.write_headers(@servlet_response)
  end

  it "should detect a chunked response when the Transfer-Encoding header is set" do
    @headers = { "Transfer-Encoding" => "chunked" }
    @response = JRuby::Rack::Response.new([@status, @headers, @body])
    @servlet_response.should_receive(:addHeader).with("Transfer-Encoding", "chunked")
    @response.write_headers(@servlet_response)
    @response.chunked?.should eql(true)
  end

  it "should write the status first, followed by the headers, and the body last" do
    @response.should_receive(:write_status).ordered
    @response.should_receive(:write_headers).ordered
    @response.should_receive(:write_body).ordered
    @response.respond(@servlet_response)
  end

  it "should forward the request if the special 'Forward' header is present" do
    response = nil
    @headers.should_receive(:[]).with("Forward").and_return(proc {|resp| response = resp})
    @response.respond(@servlet_response)
    response.should == @servlet_response
  end

  it "#getBody should call close on the body if the body responds to close" do
    @body.should_receive(:each).ordered.and_yield "hello"
    @body.should_receive(:close).ordered
    @response.getBody.should == "hello"
  end

  describe "#write_body" do
    let(:stream) do
      StubOutputStream.new.tap do |stream|
        @servlet_response.stub!(:getOutputStream).and_return stream
      end
    end

    it "does not flush after write if Transfer-Encoding header is not set" do
      @body.should_receive(:each).and_return do |block|
        block.call "hello"
        block.call "there"
      end
      @servlet_response.should_not_receive(:addHeader).with("Transfer-Encoding", "chunked")
      @response.chunked?.should eql(false)
      stream.should_receive(:write).exactly(2).times
      stream.should_not_receive(:flush)

      @response.write_body(@servlet_response)
    end

    it "writes the body to the stream and flushes when the response is chunked" do
      @headers = { "Transfer-Encoding" => "chunked" }
      @response = JRuby::Rack::Response.new([@status, @headers, @body])
      @servlet_response.should_receive(:addHeader).with("Transfer-Encoding", "chunked")
      @response.write_headers(@servlet_response)
      @response.chunked?.should eql(true)
      @body.should_receive(:each).ordered.and_return do |block|
        block.call "hello"
        block.call "there"
      end
      stream.should_receive(:write).exactly(2).times
      stream.should_receive(:flush).exactly(2).times
      @response.write_body(@servlet_response)
    end

    it "writes the body to the servlet response" do
      @body.should_receive(:each).and_return do |block|
        block.call "hello"
        block.call "there"
      end

      stream.should_receive(:write).exactly(2).times

      @response.write_body(@servlet_response)
    end

    it "calls close on the body if the body responds to close" do
      @body.should_receive(:each).ordered.and_return do |block|
        block.call "hello"
        block.call "there"
      end
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

    it "writes the stream using a channel if the object responds to #to_channel" do
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
      stream.should_receive(:write)

      @response.write_body(@servlet_response)
    end

    it "uses #transfer_to to copy the stream if available" do
      channel = mock "channel"
      @body.should_receive(:to_channel).and_return channel
      channel.stub!(:size).and_return 10
      channel.should_receive(:transfer_to).with(0, 10, anything)
      stream.should be_kind_of(java.io.OutputStream)

      @response.write_body(@servlet_response)
    end

    it "writes the stream using a channel if the object responds to #to_inputstream" do
      @body.should_receive(:to_inputstream).and_return StubInputStream.new("hello")
      stream.should be_kind_of(java.io.OutputStream)

      @response.write_body(@servlet_response)
      stream.to_s.should == "hello"
    end
  end
end
