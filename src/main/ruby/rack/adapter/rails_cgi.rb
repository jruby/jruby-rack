#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'cgi'

# Based loosely on http://github.com/macournoyer/thin/tree/master/lib/rack/adapter/rails.rb
# Adapter to run a Rails app with any supported Rack handler.
# By default it will try to load the Rails application in the
# current directory in the development environment.
# Options:
#  root: Root directory of the Rails app
#  env: Rails environment to run in (development, production or test)
# Based on http://fuzed.rubyforge.org/ Rails adapter
module Rack
  module Adapter
    class RailsCgi
      def call(env)
        request   = Request.new(env)
        response  = Response.new
        cgi       = CGIWrapper.new(request, response)
        Dispatcher.dispatch(cgi, session_options(env), response)
        response.finish
      end

      def session_options(env)
        env['rails.session_options'] || ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
      end

      class CGIWrapper < ::CGI
        def initialize(request, response, *args)
          @request  = request
          @response = response
          @args     = *args
          @input    = request.body
          super(*args)
        end

        def header(options = "text/html")
          if options.is_a?(String)
            @response['Content-Type']     = options unless @response['Content-Type']
          else
            @response['Content-Length']   = options.delete('Content-Length').to_s if options['Content-Length']

            @response['Content-Type']     = options.delete('type') || "text/html"
            @response['Content-Type']    += "; charset=" + options.delete('charset') if options['charset']

            @response['Content-Language'] = options.delete('language') if options['language']
            @response['Expires']          = options.delete('expires') if options['expires']

            @response.status              = options.delete('Status') if options['Status']

            # Convert 'cookie' header to 'Set-Cookie' headers.
            # Because Set-Cookie header can appear more the once in the response body,
            # we store it in a line break seperated string that will be translated to
            # multiple Set-Cookie header by the handler.
            if cookie = options.delete('cookie')
              cookies = []

              case cookie
              when Array then cookie.each { |c| cookies << c.to_s }
              when Hash  then cookie.each { |_, c| cookies << c.to_s }
              else            cookies << cookie.to_s
              end

              @output_cookies.each { |c| cookies << c.to_s } if @output_cookies

              @response['Set-Cookie'] = cookies unless cookies.empty?
            end

            options.each { |k,v| @response[k] = v }
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
