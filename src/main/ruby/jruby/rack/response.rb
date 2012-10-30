#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    # Takes a Rack response to map it into the Servlet world.
    # Assumes servlet containers auto-handle chunking when the output stream
    # gets flushed. Thus dechunks data if Rack chunked them, to disable this
    # behavior execute the following before delivering responses :
    #
    #  JRuby::Rack::Response.dechunk = false
    #
    # see #OrgJrubyRack::RackResponse
    class Response
      include org.jruby.rack.RackResponse
      java_import 'java.nio.ByteBuffer'
      java_import 'java.nio.channels.Channels'

      @@dechunk = true
      def self.dechunk?; @@dechunk; end
      def self.dechunk=(flag); @@dechunk = !! flag; end
      
      # Expects a Rack response: [status, headers, body].
      def initialize(array)
        @status, @headers, @body = *array
      end
      
      def getStatus
        @status
      end

      def getHeaders
        @headers
      end

      def getBody
        body = ""
        @body.each { |part| body << part }
        body
      ensure
        @body.close if @body.respond_to?(:close)
      end

      def respond(response)
        unless response.committed?
          write_status(response)
          write_headers(response)
          write_body(response)
        end
      end
      
      def write_status(response)
        response.setStatus(@status.to_i)
      end

      def write_headers(response)
        @headers.each do |k, v|
          case k
          when /^Content-Type$/i
            response.setContentType(v.to_s)
          when /^Content-Length$/i
            length = v.to_i
            # setContentLength(int) ... addHeader must be used for large files (>2GB)
            response.setContentLength(length) if ! chunked? && length < 2_147_483_648
          else
            # servlet container auto handle chunking when response is flushed 
            # (and Content-Length headers has not been set) :
            next if ( k == 'Transfer-Encoding' && v == 'chunked' && dechunk? )
            # NOTE: effectively the same as `v.split("\n").each` which is what
            # rack handler does to guard against response splitting attacks !
            # https://github.com/jruby/jruby-rack/issues/81
            if v.respond_to?(:each_line)
              v.each_line { |val| response.addHeader(k.to_s, val.chomp("\n")) }
            elsif v.respond_to?(:each)
              v.each { |val| response.addHeader(k.to_s, val.chomp("\n")) }
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
        output_stream = response.getOutputStream; body = nil
        begin
          if @body.respond_to?(:call) && ! @body.respond_to?(:each)
            @body.call(output_stream)
          elsif @body.respond_to?(:to_channel) && 
              ! object_polluted_with_anyio?(@body, :to_channel)
            body = @body.to_channel # so that we close the channel
            transfer_channel(body, output_stream)
          elsif @body.respond_to?(:to_inputstream) && 
              ! object_polluted_with_anyio?(@body, :to_inputstream)
            body = @body.to_inputstream # so that we close the stream
            transfer_channel(Channels.newChannel(body), output_stream)
          elsif @body.respond_to?(:body_parts) && @body.body_parts.respond_to?(:to_channel) && 
              ! object_polluted_with_anyio?(@body.body_parts, :to_channel)
            # ActionDispatch::Response "raw" body access in case it's a File
            body = @body.body_parts.to_channel # so that we close the channel
            transfer_channel(body, output_stream)
          else
            # 1.8 has a String#each method but 1.9 does not :
            method = @body.respond_to?(:each_line) ? :each_line : :each
            if dechunk?
              # NOTE: due Rails 3.2 stream-ed rendering http://git.io/ooCOtA#L223
              term = "\r\n"; tail = "0#{term}#{term}".freeze
              # we assume no support here for chunk-extensions e.g. 
              # chunk = chunk-size [ chunk-extension ] CRLF chunk-data CRLF
              # no need to be handled - we simply unwrap what Rails chunked :
              chunk = /^([0-9a-fA-F]+)#{Regexp.escape(term)}(.+)#{Regexp.escape(term)}/mo
              @body.send(method) do |line|
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
            else
              @body.send(method) do |line|
                output_stream.write(line.to_java_bytes)
                output_stream.flush if flush?
              end
            end
          end
        rescue LocalJumpError => e
          # HACK: deal with objects that don't comply with Rack specification
          @body = [ @body.to_s ]
          retry
        rescue NativeException => e
          # Don't needlessly raise errors because of client abort exceptions
          raise unless e.cause.toString =~ /(clientabortexception|broken pipe)/i
        ensure
          @body.close if @body.respond_to?(:close)
          body && body.close rescue nil
        end
      end

      protected
      
      # returns true if a chunked encoding is detected
      def chunked?
        return @chunked unless @chunked.nil?
        @chunked = !! ( @headers && @headers['Transfer-Encoding'] == 'chunked' )
      end
      
      # returns true if output (body) should be flushed after each written line
      def flush?
        chunked? || ! ( @headers && @headers['Content-Length'] )
      end
      
      # this should be true whenever the response should be de-chunked
      def dechunk?
        self.class.dechunk? && chunked?
      end
      
      private
      
      BUFFER_SIZE = 16 * 1024
      
      def transfer_channel(channel, output_stream)
        output_channel = Channels.newChannel output_stream
        if channel.respond_to?(:transfer_to)
          channel.transfer_to(0, channel.size, output_channel)
        else
          buffer = ByteBuffer.allocate(BUFFER_SIZE)
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

      @@object_polluted = begin
                            # Fixnum should not have this method, and it
                            # shouldn't be on Object
                            Fixnum.method('to_channel').owner == Object
                          rescue
                            false
                          end
      
      # See http://bugs.jruby.org/5444 - we need to account for pre-1.6
      # JRuby where Object was polluted with #to_channel by
      # IOJavaAddions.AnyIO
      def object_polluted_with_anyio?(obj, meth)
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
