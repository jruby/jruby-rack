#--
# Based on the fuzed adapter -- snapshot retrieved from:
# http://repo.or.cz/w/fuzed.git?a=blob_plain;f=bin/fuzed-adapter;h=7bdfbf15afa27fdad31b24fe719712c51f693809
# 
# Also based on the thin adapter:
# http://github.com/macournoyer/thin/tree/master/lib/rack/adapter/rails.rb
#
# Perhaps this will show up in Rack someday and this won't be needed
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
              
              @response['Set-Cookie'] = [@response['Set-Cookie'], cookies].compact.join("\n")
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
