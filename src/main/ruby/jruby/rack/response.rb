#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    class Response
      include Java::org.jruby.rack.RackResponse
      java_import java.nio.channels.Channels

      @@object_polluted = begin
                            # Fixnum should not have this method, and it
                            # shouldn't be on Object
                            Fixnum.method('to_channel').owner == Object
                          rescue
                            false
                          end

      def initialize(arr)
        @status, @headers, @body = *arr
      end

      def getStatus
        @status
      end

      def getHeaders
        @headers
      end

      def chunked?
        (@headers && @headers['Transfer-Encoding'] == "chunked")
      end

      def getBody
        b = ""
        @body.each {|part| b << part }
        b
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
            # setContentLength accepts only int, addHeader must be used for large files (>2GB)
            response.setContentLength(length) unless chunked? || length >= 2_147_483_648
          else
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
        outputstream = response.getOutputStream
        begin
          if @body.respond_to?(:call) && ! @body.respond_to?(:each)
            @body.call(outputstream)
          elsif @body.respond_to?(:to_channel) && !object_polluted_with_anyio?(@body, :to_channel)
            @body = @body.to_channel # so that we close the channel
            transfer_channel(@body, outputstream)
          elsif @body.respond_to?(:to_inputstream) && !object_polluted_with_anyio?(@body, :to_inputstream)
            @body = @body.to_inputstream # so that we close the stream
            transfer_channel(Channels.newChannel(@body), outputstream)
          else
            # 1.8 has a String#each method but 1.9 does not :
            method = @body.respond_to?(:each_line) ? :each_line : :each
            @body.send(method) do |line|
              outputstream.write(line.to_java_bytes)
              outputstream.flush if chunked?
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
        end
      end

      def transfer_channel(channel, outputstream)
        outputchannel = Channels.newChannel outputstream
        if channel.respond_to?(:transfer_to)
          channel.transfer_to(0, channel.size, outputchannel)
        else
          buffer = java.nio.ByteBuffer.allocate(16384)
          while channel.read(buffer) != -1
            buffer.flip
            outputchannel.write(buffer)
            buffer.compact
          end
          buffer.flip
          while buffer.has_remaining
            outputchannel.write(buffer)
          end
        end
      end

      # See http://bugs.jruby.org/5444 - we need to account for pre-1.6
      # JRuby where Object was polluted with #to_channel by
      # IOJavaAddions.AnyIO
      def object_polluted_with_anyio?(obj, meth)
        begin
          # The object should not have this method, and
          # it shouldn't be on Object
          @@object_polluted && obj.method(meth).owner == Object
        rescue
          false
        end
      end
    end
  end
end
