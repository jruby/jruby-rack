#--
# Copyright (c) 2007,2008, Dave Fayram, Tom Preston-Werner
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the <ORGANIZATION> nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Snapshot retrieved from:
# http://repo.or.cz/w/fuzed.git?a=blob_plain;f=bin/fuzed-adapter;h=7bdfbf15afa27fdad31b24fe719712c51f693809
#++

unless defined? RAILS_ROOT
  raise "Rails' environment has to be loaded before using Rack::Adapter::Rails"
end

require "rack/request"
require "rack/response"
require "dispatcher"

class ActionController::CgiRequest #:nodoc:
  # Replace session_options writer to merge session options
  # With ones passed into request (so we can preserve the
  # java servlet request)
  def session_options=(opts)
    if opts == false
      @session_options = false
    elsif @session_options
      @session_options.update(opts)
    else
      @session_options = opts
    end
  end
end if defined?(::ActionController)

module Rack
  module Adapter
    class Rails
      def call(env)
        request = Request.new(env)
        response = Response.new

        cgi = CGIStub.new(request, response)

        Dispatcher.dispatch(cgi, session_options(env), response)

        response.finish
      end

      protected
      def session_options(env)
	env['rails.session_options'] || ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
      end

      class CGIStub < ::CGI

        def initialize(request, response, *args)
          @request = request
          @response = response
          @args = *args
          @input = request.body
          super(*args)
        end

        IGNORED_HEADERS = [ "Status" ]

        def header(options = "text/html")
          # puts 'header---------------'
          # p options
          # puts '---------------------'

          if options.instance_of?(String)
            @response['Content-Type'] = options unless @response['Content-Type']
          else
            @response['Content-Length'] = options.delete('Content-Length').to_s if options['Content-Length']

            @response['Content-Type'] = options.delete('type') || "text/html"
            @response['Content-Type'] += "; charset=" + options.delete('charset') if options['charset']

            @response['Status'] = options.delete('Status') if options['Status']
            @response['Content-Language'] = options.delete('language') if options['language']
            @response['Expires'] = options.delete('expires') if options['expires']

            IGNORED_HEADERS.each {|k| options.delete(k) }

            options.each{|k,v| @response[k] = v}

            # convert 'cookie' header to 'Set-Cookie' headers
            if cookie = @response['cookie']
              case cookie
                when Array
                  cookie.each {|c| @response['Set-Cookie'] = c.to_s }
                when Hash
                  cookie.each_value {|c| @response['Set-Cookie'] = c.to_s}
                else
                  @response['Set-Cookie'] = options['cookie'].to_s
              end

              @output_cookies.each { |c| @response['Set-Cookie'] = c.to_s } if @output_cookies
            end
          end

          ""
        end

        def params
          @params ||= @request.params
        end

        def cookies
          @request.cookies
        end

        def query_string
          @request.query_string
        end

        # Used to wrap the normal args variable used inside CGI.
        def args
          @args
        end

        # Used to wrap the normal env_table variable used inside CGI.
        def env_table
          @request.env
        end

        # Used to wrap the normal stdinput variable used inside CGI.
        def stdinput
          @input
        end

        def stdoutput
          STDERR.puts "stdoutput should not be used."
          @response.body
        end
      end
    end
  end
end
