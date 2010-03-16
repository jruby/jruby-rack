#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'action_controller'

module ActionController
  class CgiRequest #:nodoc:
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

    DEFAULT_SESSION_OPTIONS = {} unless defined?(DEFAULT_SESSION_OPTIONS)
  end

  class Base
    def servlet_request
      request.env['java.servlet_request']
    end

    def render_with_servlet_response(&block)
      if block
        @performed_render = true
        response.headers['Forward'] = block
      end
    end

    def forward_to(url)
      req = servlet_request
      render_with_servlet_response do |resp|
        req.getRequestDispatcher(url).forward(req, resp)
      end
    end
  end

  # These rescue module overrides should only be needed for pre-Rails 2.1
  unless defined?(::Rails.public_path)
    module Rescue
      # Rails 2.0 static rescue files
      def render_optional_error_file(status_code) #:nodoc:
        status = interpret_status(status_code)
        path = "#{PUBLIC_ROOT}/#{status[0,3]}.html"
        if File.exists?(path)
          render :file => path, :status => status
        else
          head status
        end
      end

      def rescue_action_in_public(exception) #:nodoc:
        if respond_to?(:render_optional_error_file) # Rails 2
          render_optional_error_file response_code_for_rescue(exception)
        else # Rails 1
          case exception
          when RoutingError, UnknownAction
            render_text(IO.read(File.join(PUBLIC_ROOT, '404.html')), "404 Not Found")
          else
            render_text(IO.read(File.join(PUBLIC_ROOT, '500.html')), "500 Internal Error")
          end
        end
      end
    end
  end
end

module JRuby::Rack
  SESSION_OPTIONS = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
end
