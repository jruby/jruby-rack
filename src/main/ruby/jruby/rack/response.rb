#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'

module JRuby
  module Rack
    # Takes a Rack response to map it into the Servlet world.
    #
    # Assumes servlet containers auto-handle chunking when the output stream
    # gets flushed. Thus de-chunks data if Rack chunked them, to disable this
    # behavior execute the following before delivering responses :
    #
    #   JRuby::Rack::Response.dechunk = false
    #
    # @see #Java::OrgJrubyRack::RackResponse
    class Response
      include org.jruby.rack.RackResponse
      java_import 'java.nio.ByteBuffer'
      java_import 'java.nio.channels.Channels'

      @@swallow_client_abort = true
      # Whether we swallow client abort exceptions (EOF received on the socket).
      def self.swallow_client_abort?; @@swallow_client_abort; end
      def self.swallow_client_abort=(flag); @@swallow_client_abort = !! flag; end

      @@dechunk = nil
      # Whether responses should de-chunk data (when chunked response detected).
      def self.dechunk?; @@dechunk; end
      def self.dechunk=(flag); @@dechunk = !! flag; end

      @@channel_chunk_size = 32 * 1024 * 1024 # 32 MB
      # Returns the channel chunk size to be used e.g. when a (send) file
      # response is detected. By setting this value to nil you force an "explicit"
      # byte buffer to be used when copying between channels.
      # @note High values won't hurt when sending small files since most Java
      # (file) channel implementations handle this gracefully. However if you're
      # on Windows it is  recommended to not set this higher than the "magic"
      # number (64 * 1024 * 1024) - (32 * 1024) as there seems to be anecdotal
      # evidence that attempts to transfer more than 64MB at a time on certain
      # Windows versions results in a slow copy.
      # @see #channel_buffer_size
      def self.channel_chunk_size; @@channel_chunk_size; end
      def self.channel_chunk_size=(size); @@channel_chunk_size = size; end
      def channel_chunk_size; self.class.channel_chunk_size; end

      @@channel_buffer_size = 16 * 1024 # 16 kB
      # Returns a byte buffer size that will be allocated when copying between
      # channels. This usually won't happen at all (unless you return an exotic
      # channel backed object) as with file responses the response channel is
      # always transferable and thus {#channel_chunk_size} will be used.
      # @see #channel_chunk_size
      def self.channel_buffer_size; @@channel_buffer_size; end
      def self.channel_buffer_size=(size); @@channel_buffer_size = size; end
      def channel_buffer_size; self.class.channel_buffer_size; end

      # Expects a Rack response: [status, headers, body].
      def initialize(array)
        @status, @headers, @body = *array
      end

      # Return the response status.
      # @return [Integer]
      # @see #Java::OrgJrubyRack::RackResponse#getStatus
      def getStatus
        @status
      end

      # Return the headers hash.
      # @return [Hash]
      # @see #Java::OrgJrubyRack::RackResponse#getHeaders
      def getHeaders
        @headers
      end

      # Return the response body.
      # @return [String]
      # @see #Java::OrgJrubyRack::RackResponse#getBody
      def getBody
        body = ''.dup
        @body.each { |part| body << part }
        body
      ensure
        @body.close if @body.respond_to?(:close)
      end

      # Respond this response with the given (Servlet) response environment.
      # @param [Java::OrgJrubyRack::RackResponseEnvironment]
      # @see #Java::OrgJrubyRack::RackResponse#respond
      def respond(response)
        unless response.committed?
          write_status(response)
          write_headers(response)
          write_body(response)
        end
      end

      # Writes the response status.
      # @see #respond
      def write_status(response)
        response.setStatus(@status.to_i)
      end

      TRANSFER_ENCODING = 'Transfer-Encoding'.freeze # :nodoc

      # Writes the response headers.
      # @see #respond
      def write_headers(response)
        @headers.each do |key, value|
          case key
          when /^Content-Type$/i
            response.setContentType(value.to_s)
          when /^Content-Length$/i
            length = value.to_i
            # setContentLength(int) ... addHeader must be used for large files (>2GB)
            response.setContentLength(length) if ! chunked? && length < 2_147_483_648
          else
            # servlet container auto handle chunking when response is flushed
            # (and Content-Length headers has not been set) :
            next if key == TRANSFER_ENCODING && skip_encoding_header?(value)
            # NOTE: effectively the same as `v.split("\n").each` which is what
            # rack handler does to guard against response splitting attacks !
            # https://github.com/jruby/jruby-rack/issues/81
            if value.respond_to?(:each_line)
              value.each_line { |val| response.addHeader(key.to_s, val.chomp("\n")) }
            elsif value.respond_to?(:each)
              value.each { |val| response.addHeader(key.to_s, val.chomp("\n")) }
            else
              case value
              when Numeric
                response.addIntHeader(key.to_s, value.to_i)
              when Time
                response.addDateHeader(key.to_s, value.to_i * 1000)
              else
                response.addHeader(key.to_s, value.to_s)
              end
            end
          end
        end
      end

      # Writes the response body.
      # @see #respond
      def write_body(response)
        body = nil
        begin
          if @body.respond_to?(:call) && ! @body.respond_to?(:each)
            @body.call response.getOutputStream
          elsif @body.respond_to?(:to_path) # send_file
            send_file @body.to_path, response
          elsif @body.respond_to?(:to_channel) &&
              ! object_polluted_with_anyio?(@body, :to_channel)
            body = @body.to_channel # so that we close the channel
            transfer_channel body, response.getOutputStream
          elsif @body.respond_to?(:to_inputstream) &&
              ! object_polluted_with_anyio?(@body, :to_inputstream)
            body = @body.to_inputstream # so that we close the stream
            body = Channels.newChannel(body) # closing the channel closes the stream
            transfer_channel body, response.getOutputStream
          elsif @body.respond_to?(:body_parts) && @body.body_parts.respond_to?(:to_channel) &&
              ! object_polluted_with_anyio?(@body.body_parts, :to_channel)
            # ActionDispatch::Response "raw" body access in case it's a File
            body = @body.body_parts.to_channel # so that we close the channel
            transfer_channel body, response.getOutputStream
          else
            if dechunk?
              write_body_dechunked response.getOutputStream
            else
              output_stream = response.getOutputStream
              # 1.8 has a String#each method but 1.9 does not :
              method = @body.respond_to?(:each_line) ? :each_line : :each
              @body.send(method) do |line|
                output_stream.write(line.to_java_bytes)
                output_stream.flush if flush?
              end
            end
          end
        rescue LocalJumpError
          # HACK: deal with objects that don't comply with Rack specification
          @body = [ @body.to_s ]
          retry
        rescue java.io.IOException => e
          raise e if ! client_abort_exception?(e) || ! self.class.swallow_client_abort?
        ensure
          @body.close if @body.respond_to?(:close)
          body && body.close rescue nil
        end
      end

      protected

      # @return [true, false] whether a chunked encoding is detected
      def chunked?
        return @chunked unless @chunked.nil?
        @chunked = !! ( @headers && @headers[TRANSFER_ENCODING] == 'chunked' )
      end

      # @return [true, false] whether output (body) should be flushed after each
      # written (yielded) line
      # @see #chunked?
      def flush?
        chunked? || ! ( @headers && @headers['Content-Length'] )
      end

      # Whether de-chunking (a chunked Rack response) should be performed.
      # @see JRuby::Rack::Response#dechunk?
      # @see #chunked?
      def dechunk?
        self.class.dechunk? && chunked?
      end

      # Sends a file when a Rails/Rack file response (`body.to_path`) is detected.
      # This allows for potential application server overrides when file streaming.
      # By default JRuby-Rack will stream the file using a (native) file channel.
      #
      # @param path the file path
      # @param response the response environment
      #
      # @note That this is not related to `Rack::Sendfile` support, since if you
      # have configured *sendfile.type* (e.g. to Apache's "X-Sendfile") this part
      # would not have been executing at all.
      def send_file(path, response)
        input = java.io.FileInputStream.new(path.to_s)
        channel = input.getChannel
        begin
          transfer_channel channel, response.getOutputStream
        ensure
          channel.close
          input.close rescue nil
        end
      end

      private

      def client_abort_exception?(ioe)
        ioe.inspect =~ /(ClientAbortException|EofException|broken pipe)/i
      end

      def skip_encoding_header?(value)
        value == 'chunked' && @@dechunk != false
      end

      def write_body_dechunked(output_stream)
        # NOTE: due Rails 3.2 stream-ed rendering http://git.io/ooCOtA#L223
        # Only required if the patch at jruby/rack/chunked.rb is not applied ...
        term = "\r\n"; tail = "0#{term}#{term}".freeze
        # we assume no support here for chunk-extensions e.g.
        # chunk = chunk-size [ chunk-extension ] CRLF chunk-data CRLF
        # no need to be handled - we simply unwrap what Rails chunked :
        chunk = /^([0-9a-fA-F]+)#{Regexp.escape(term)}(.+)#{Regexp.escape(term)}/mo
        @body.send(@body.respond_to?(:each_line) ? :each_line : :each) do |line|
          if line == tail
            # "0\r\n\r\n" NOOP
          elsif line =~ chunk # (size.to_s(16)) term (chunk) term
            if $1.to_i(16) == $2.bytesize
              output_stream.write $2.to_java_bytes
            else
              output_stream.write line.to_java_bytes
            end
          else # seems it's not a chunk ... thus let it flow :
            output_stream.write line.to_java_bytes
          end
          output_stream.flush
        end
      end

      def transfer_channel(channel, output_stream)
        output_channel = Channels.newChannel output_stream
        if channel.respond_to?(:transfer_to) && channel_chunk_size # FileChannel
          pos = 0; size = channel.size; while pos < size
            # for small sizes Java will (correctly) "ignore" the large chunk :
            pos += channel.transfer_to(pos, channel_chunk_size, output_channel)
          end
        else
          buffer = ByteBuffer.allocate(channel_buffer_size)
          while channel.read(buffer) != -1
            buffer.flip
            output_channel.write(buffer)
            buffer.compact
          end
          buffer.flip
          while buffer.has_remaining
            output_channel.write(buffer)
          end
        end
      end

      # Fixnum should not have this method, and it shouldn't be on Object
      @@object_polluted = ( Fixnum.method(:to_channel).owner == Object ) rescue nil # :nodoc

      # See http://bugs.jruby.org/5444 - we need to account for pre-1.6 JRuby
      # where Object was polluted with #to_channel ( by IOJavaAddions.AnyIO )
      def object_polluted_with_anyio?(obj, meth) # :nodoc
        @@object_polluted && begin
          # The object should not have this method, and
          # it shouldn't be on Object
          obj.method(meth).owner == Object
        rescue
          false
        end
      end

    end
  end
end
