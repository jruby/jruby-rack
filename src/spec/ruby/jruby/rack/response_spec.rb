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

  let(:response) do
    status, headers, body = 200, { 'Content-Type' => 'bogus' }, ['<h1>Hello</h1>']
    JRuby::Rack::Response.new [status, headers, body]
  end

  let(:servlet_response) { javax.servlet.http.HttpServletResponse.impl {} }

  let(:response_environment) { new_response_environment(servlet_response) }

  it "converts status to integer" do
    response = JRuby::Rack::Response.new ['202', {}, ['']]
    expect(response.to_java.getStatus).to eql 202
  end

  it "returns status, headers and body" do
    expect(response.to_java.getStatus).to eql 200
    expect(response.to_java.getHeaders['Content-Type']).to eql 'bogus'
    expect(response.to_java.getBody).to eql "<h1>Hello</h1>"
  end

  it "writes the status to the servlet response" do
    expect(servlet_response).to receive(:setStatus).with(200)
    response.write_status(response_environment)
  end

  it "writes the headers to the servlet response" do
    response.to_java.getHeaders.update({
                                         "Content-Type" => "text/html",
                                         "Content-Length" => '20',
                                         "Server" => "Apache/2.2.x"
                                       })
    expect(servlet_response).to receive(:setContentType).with("text/html")
    expect(servlet_response).to receive(:setContentLength).with(20)
    expect(servlet_response).to receive(:addHeader).with("Server", "Apache/2.2.x")
    response.write_headers(response_environment)
  end

  it "accepts (non-array) body that responds to each" do
    require 'stringio'
    response = JRuby::Rack::Response.new ['202', {}, StringIO.new("1\n2\n3")]
    expect(response.to_java.getBody).to eql "1\n2\n3"
  end

  it "writes headers with multiple values multiple addHeader invocations" do
    response.to_java.getHeaders.update({
                                         "Content-Type" => "text/html",
                                         "Content-Length" => '20',
                                         "Set-Cookie" => %w(cookie1 cookie2)
                                       })
    expect(servlet_response).to receive(:setContentType).with("text/html")
    expect(servlet_response).to receive(:setContentLength).with(20)
    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie1")
    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie2")
    response.write_headers(response_environment)
  end

  it "writes headers whose value contains newlines as multiple addHeader invocations" do
    response.to_java.getHeaders.update({ "Set-Cookie" => "cookie1\ncookie2" })
    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie1")
    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie2")
    response.write_headers(response_environment)
  end

  it "writes headers whose value contains newlines as multiple addHeader invocations when string doesn't respond to #each" do
    value = "cookie1\ncookie2"
    class << value
      undef_method :each;
    end if value.respond_to?(:each)
    response.to_java.getHeaders.update({ "Set-Cookie" => value })

    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie1")
    expect(servlet_response).to receive(:addHeader).with("Set-Cookie", "cookie2")
    response.write_headers(response_environment)
  end

  it "adds an int header when values is a fixnum" do
    update_response_headers "Expires" => 0
    expect(response_environment).to receive(:addIntHeader).with("Expires", 0)
    response.write_headers(response_environment)
  end

  it "adds date header when value is date" do
    update_response_headers "Last-Modified" => time = Time.now
    millis = (time.to_f * 1000.0).to_i
    expect(servlet_response).to receive(:addDateHeader).with("Last-Modified", millis)
    response.write_headers(response_environment)
  end

  it "writes the status first, followed by headers, and body last" do
    expect(servlet_response).to receive(:isCommitted).and_return false
    expect(response).to receive(:write_status).ordered
    expect(response).to receive(:write_headers).ordered
    expect(response).to receive(:write_body).ordered
    response.to_java.respond(response_environment)
  end

  it "does not write status, headers or body if the request is committed (was forwarded)" do
    expect(servlet_response).to receive(:isCommitted).and_return true
    response.to_java.respond(response_environment)
  end

  it "calls close on the body if the body responds to close" do
    body = double('body')
    expect(body).to receive(:each).ordered.and_yield "hello"
    expect(body).to receive(:close).ordered
    response = JRuby::Rack::Response.new ['200', {}, body]
    response.to_java.getBody
  end

  it "detects a chunked response when the Transfer-Encoding header is set" do
    headers = { "Transfer-Encoding" => "chunked" }
    response = JRuby::Rack::Response.new [200, headers, ['body']]
    # NOTE: servlet container auto handle chunking when flushed no need to set :
    expect(servlet_response).not_to receive(:addHeader).with("Transfer-Encoding", "chunked")
    response.write_headers(response_environment)
    expect(response.chunked?).to be true
  end

  describe "#write_body" do

    let(:stream) do
      stream = StubOutputStream.new
      allow(response_environment).to receive(:getOutputStream).and_return stream
      stream
    end

    before(:each) { self.stream }

    it "writes the body to the stream and flushes when the response is chunked" do
      headers = { "Transfer-Encoding" => "chunked" }
      response = JRuby::Rack::Response.new [200, headers, ['hello', 'there']]
      expect(stream).to receive(:write).exactly(2).times
      expect(stream).to receive(:flush).exactly(2).times

      # NOTE: servlet container auto handle chunking when flushed no need to set :
      expect(response_environment).not_to receive(:addHeader).with("Transfer-Encoding", "chunked")
      response.write_headers(response_environment)
      expect(response.chunked?).to be true

      response.write_body(response_environment)
    end

    it "dechunks the body when a chunked response is detected",
       :lib => [:rails23, :rails31, :rails32, :rails40] do
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
        body = Rack::Chunked::Body.new body
        response = JRuby::Rack::Response.new([200, headers, body])
        response.write_headers(response_environment)

        times = 0
        expect(stream).to receive(:write).exactly(6).times do |bytes|
          str = String.from_java_bytes(bytes)
          str = str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
          case times += 1
          when 1 then expect(str).to eq "1"
          when 2 then expect(str).to eq "\nsecond chunk"
          when 3 then expect(str).to eq "a multi\nline chunk \n42"
          when 4 then expect(str).to eq "utf-8 chunk 'ty píčo'!\n"
          when 5 then expect(str).to eq "terminated chunk\r\n"
          when 6 then expect(str).to eq "\r\nthe very\r\n last\r\n\r\n chunk"
          else
            fail("unexpected :write received with #{str.inspect}")
          end
        end
        expect(stream).to receive(:flush).exactly(6 + 1).times # +1 for tail chunk

        response.write_body(response_environment)
      end
    end

    it "does not dechunk body when dechunkins is turned off",
       :lib => [:rails31, :rails32, :rails40] do
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
        response = JRuby::Rack::Response.new([200, headers, body])

        response.write_headers(response_environment)

        times = 0
        expect(stream).to receive(:write).exactly(3).times do |bytes|
          str = String.from_java_bytes(bytes)
          case times += 1
          when 1 then expect(str).to eq "1\r\n1\r\n"
          when 2 then expect(str).to eq "d\r\n\nsecond chunk\r\n"
          when 3 then expect(str).to eq "0\r\n\r\n"
          else
            fail("unexpected :write received with #{str.inspect}")
          end
        end
        expect(stream).to receive(:flush).exactly(3).times

        response.write_body(response_environment)

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
      response = JRuby::Rack::Response.new([200, headers, body])

      response.write_headers(response_environment)

      times = 0
      expect(stream).to receive(:write).exactly(5).times do |bytes|
        str = String.from_java_bytes(bytes)
        case times += 1
        when 1 then expect(str).to eq "1"
        when 2 then expect(str).to eq "a multi\nline chunk \n42"
        when 3 then expect(str).to eq "\r\nthe very\r\n last\r\n\r\n chunk"
        when 4 then
          str = str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
          expect(str).to eq "7\r\nty píčo\r\n"
        when 5 then expect(str).to eq "21\r\n a chunk with an invalid length \r\n"
        else
          fail("unexpected :write received with #{str.inspect}")
        end
      end
      expect(stream).to receive(:flush).exactly(5).times

      response.write_body(response_environment)
    end

    it "flushes the body (parts) when no content-length set" do
      response = JRuby::Rack::Response.new [200, {}, ['hello', 'there']]

      response.write_headers(response_environment)

      expect(stream).to receive(:write).once.ordered
      expect(stream).to receive(:flush).once.ordered
      expect(stream).to receive(:write).once.ordered
      expect(stream).to receive(:flush).once.ordered
      response.write_body(response_environment)
    end

    it "does not flush the body when content-length set" do
      headers = { "Content-Length" => 10 }
      response = JRuby::Rack::Response.new [200, headers, ['hello', 'there']]

      response.write_headers(response_environment)

      # expect(stream).to receive(:write).twice
      expect(stream).to receive(:flush).never
      response.write_body(response_environment)
    end

    it "writes the body to the servlet response" do
      response = JRuby::Rack::Response.new [200, {}, ['1', '2', '3']]

      expect(stream).to receive(:write).exactly(3).times
      response.write_body(response_environment)
    end

    it "calls close on the body if the body responds to close" do
      body = double('body')
      expect(body).to receive(:each).ordered.and_yield("hello").and_yield("there")
      expect(body).to receive(:close).ordered
      response = JRuby::Rack::Response.new [200, {}, body]

      expect(stream).to receive(:write).exactly(2).times
      response.write_body(response_environment)
    end

    #    it "yields the stream to an object that responds to #call" do
    #      body = Proc.new { |stream| stream.write '42'.to_java_bytes }
    #      response = JRuby::Rack::Response.new [ 200, {}, body ]
    #
    #      expect(stream).to receive(:write).with('42').once
    #      response.write_body(response_environment)
    #    end

    it "does not yield the stream if the object responds to both #call and #each" do
      response = JRuby::Rack::Response.new [200, {}, body = ['body']]

      def body.call
        raise 'yielded'
      end

      expect(stream).to receive(:write)
      response.write_body(response_environment)
    end

    it "writes a (Tempfile) stream using a channel" do
      body = (require 'tempfile'; Tempfile.new 'to_channel_spec')
      body << "1234567890"; body << "\n"; body << '1234567890'; body.rewind

      def body.each
        raise "each not-expected";
      end

      def body.each_line
        raise "each_line not-expected";
      end

      class << body
        undef_method :to_path;
      end if body.respond_to?(:to_path)

      response = JRuby::Rack::Response.new [200, {}, body]

      response.write_body(response_environment)
      expect(stream.to_s).to eql "1234567890\n1234567890"
      expect { body.to_channel }.to raise_error IOError, /closed/
    end

    it "writes a (StringIO) stream using a channel" do
      body = (require 'stringio'; StringIO.new '')
      body << "1234567890"; body << "\n"; body << '1234567890'; body.rewind

      def body.each
        raise "each not-expected";
      end

      def body.each_line
        raise "each_line not-expected";
      end

      response = JRuby::Rack::Response.new [200, {}, body]

      response.write_body(response_environment)
      expect(stream.to_s).to eql "1234567890\n1234567890"
      expect { body.to_channel }.not_to raise_error
    end

    it "streams a file using a channel if wrapped in body_parts",
       :lib => [:rails30, :rails31, :rails32] do
      body = wrap_file_body path =
                              File.expand_path('../../files/image.jpg', File.dirname(__FILE__))

      stream = self.stream
      response = JRuby::Rack::Response.new [200, body.headers, body]

      response.write_body(response_environment)
      expect_eql_java_bytes stream.to_java_bytes, File.read(path).to_java_bytes
    end

    it "closes original body during write_body", :lib => [:rails30, :rails31, :rails32] do
      body = wrap_file_body File.expand_path('../../files/image.jpg', File.dirname(__FILE__))

      response = JRuby::Rack::Response.new [200, body.headers, body]
      expect(body).to receive(:close)

      response.write_body(response_environment)
    end

    private

    def wrap_file_body(path)
      # Rails style when doing #send_file
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

    it "sends a file when file (body) response detected" do
      path = File.expand_path('../../files/image.jpg', File.dirname(__FILE__))

      response = JRuby::Rack::Response.new [200, {}, FileBody.new(path)]
      expect(response).to receive(:send_file) do |path, response|
        expect(path).to eql path
        expect(response).to be response_environment
      end
      response.write_body(response_environment)
    end

    # Similar to {ActionController::DataStreaming::FileBody}
    class FileBody

      attr_reader :to_path

      def initialize(path)
        @to_path = path
      end

      # Stream the file's contents if Rack::Sendfile isn't present.
      def each
        File.open(to_path, 'rb') do |file|
          while chunk = file.read(16384)
            yield chunk
          end
        end
      end

    end

    it "swallows client abort exceptions by default" do
      allow(response_environment).to receive(:getOutputStream).and_return BrokenPipeOutputStream.new
      with_swallow_client_abort do
        response.write_body response_environment
      end
    end

    class BrokenPipeOutputStream < StubOutputStream

      def flush
        raise java.io.EOFException.new 'broken pipe'
      end

    end

    it "raises client abort exceptions if not set to swallow" do
      allow(response_environment).to receive(:getOutputStream).and_return BrokenPipeOutputStream.new
      begin
        with_swallow_client_abort(false) do
          response.write_body response_environment
        end
        fail 'EOF exception NOT raised!'
      rescue java.io.IOException => e
        expect(e.to_s).to match(/broken pipe/i)
      end
    end

    it "raises exceptions that do not look like abort exceptions" do
      allow(response_environment).to receive(:getOutputStream).and_return BrokenCigarOutputStream.new
      begin
        response.write_body response_environment
        fail 'IO exception NOT raised!'
      rescue java.io.IOException => e
        expect(e.to_s).to match(/broken cigar/i)
      end
    end

    class BrokenCigarOutputStream < StubOutputStream

      def flush
        raise java.io.IOException.new 'broken cigar'
      end

    end

    it "raises client abort exceptions if not set to swallow ('Broken pipe')" do
      servlet_response = org.jruby.rack.mock.fail.FailingHttpServletResponse.new
      servlet_response.setFailure java.io.IOException.new 'Broken pipe'
      begin
        with_swallow_client_abort(false) do
          response.write_body new_response_environment(servlet_response)
        end
        fail 'EOF exception NOT raised!'
      rescue java.io.IOException
      end
    end

    it "swallows client abort exceptions (Tomcat-like ClientAbortException)" do
      servlet_response = org.jruby.rack.mock.fail.FailingHttpServletResponse.new
      servlet_response.setFailure org.jruby.rack.mock.fail.ClientAbortException.new java.io.IOException.new
      with_swallow_client_abort do
        response.write_body new_response_environment(servlet_response)
      end
    end

    it "swallows client abort exceptions (Jetty-like EofException)" do
      servlet_response = org.jruby.rack.mock.fail.FailingHttpServletResponse.new
      servlet_response.setFailure org.jruby.rack.mock.fail.EofException.new
      with_swallow_client_abort do
        response.write_body new_response_environment(servlet_response)
      end
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

    def with_swallow_client_abort(client_abort = true)
      begin
        prev_client_abort = JRuby::Rack::Response.swallow_client_abort?
        JRuby::Rack::Response.swallow_client_abort = client_abort
        yield
      ensure
        JRuby::Rack::Response.swallow_client_abort = prev_client_abort
      end
    end

  end

  private

  def update_response_headers(headers)
    response.to_java.getHeaders.update(headers)
  end

  def new_response_environment(this_servlet_response = servlet_response)
    org.jruby.rack.RackResponseEnvironment.impl do |name, *args|
      this_servlet_response.send(name, *args)
    end
  end

end
