#--
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

      def write_body_dechunked(output_stream)
        # NOTE: due Rails 3.2 stream-ed rendering http://git.io/ooCOtA#L223
        # Only required if the patch at jruby/rack/chunked.rb is not applied ...
        term = "\r\n"; tail = "0#{term}#{term}".freeze
        # we assume no support here for chunk-extensions e.g.
        # chunk = chunk-size [ chunk-extension ] CRLF chunk-data CRLF
        # no need to be handled - we simply unwrap what Rails chunked :
        chunk = /^([0-9a-fA-F]+)#{Regexp.escape(term)}(.+)#{Regexp.escape(term)}/mo
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

    end
  end
end
