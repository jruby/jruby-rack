#--
# Copyright (c) 2013-2014 Karol Bucek, LTD.
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

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
    #
    # @note Most parts of this class are implemented as `org.jruby.rack.ext.Response`.
    class Response

      private

      # Writes a Rack 3 "streaming" response body - one that responds to +call+
      # (and not +each+) - by handing it a +stream+ that wraps the (servlet)
      # response output. The body's +call+ is invoked once; the stream is
      # always closed afterwards.
      # @see https://github.com/rack/rack/blob/main/SPEC.rdoc ("Streaming Body")
      # @note invoked from `org.jruby.rack.ext.Response#writeBody`
      def write_streaming_body(output_stream)
        stream = Stream.new(output_stream)
        body.call(stream)
      ensure
        stream.close if stream
      end

      def write_body_dechunked(output_stream)
        # NOTE: due Rails 3.2 stream-ed rendering http://git.io/ooCOtA#L223
        # Only required if the patch at jruby/rack/chunked.rb is not applied ...
        term = "\r\n"; tail = "0#{term}#{term}".freeze
        term = Regexp.escape(term)
        # we assume no support here for chunk-extensions e.g.
        # chunk = chunk-size [ chunk-extension ] CRLF chunk-data CRLF
        # no need to be handled - we simply unwrap what Rails chunked :
        chunk = /^([0-9a-fA-F]+)#{term}(.+)#{term}/mo
        body.send(body.respond_to?(:each_line) ? :each_line : :each) do |line|
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

      # The +stream+ handed to a streaming (`#call`) response body. Wraps the
      # (servlet) response output stream to provide the +IO+-like interface the
      # Rack SPEC requires of a streaming body's stream argument: +read+,
      # +write+, +<<+, +flush+, +close+, +close_read+, +close_write+, +closed?+.
      #
      # It is write-only - a servlet response output stream cannot be read from
      # (full bi-directional hijack is not possible over the servlet API) - so
      # +read+/+close_read+ are no-ops. This still covers the common case of
      # one-directional streaming (SSE, long-poll, progressive rendering).
      #
      # @private only handed to a streaming body by #write_streaming_body
      class Stream

        def initialize(output_stream)
          @output = output_stream
          @closed = false
        end

        def closed?
          @closed
        end

        # Writes the given data, flushing so the client receives it promptly
        # (the whole point of a streaming body). Returns the number of bytes.
        def write(data)
          raise IOError, 'closed stream' if closed?
          string = data.is_a?(String) ? data : data.to_s
          @output.write(string.to_java_bytes)
          @output.flush
          string.bytesize
        end

        def <<(data)
          write(data)
          self
        end

        def flush
          @output.flush unless closed?
          self
        end

        # A response stream is write-only; there is nothing to read.
        def read(*)
          nil
        end

        def close_read
          nil
        end

        def close
          return if closed?
          @closed = true
          begin
            @output.close
          rescue java.io.IOException, java.lang.IllegalStateException
            # response already committed / client gone - nothing we can do
          end
          nil
        end
        alias_method :close_write, :close
      end
      private_constant :Stream

    end
  end
end
