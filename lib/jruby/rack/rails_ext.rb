#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

if defined?(::ActionController)
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
  end

  module ActionController::Rescue
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
      if respond_to?(:response_code_for_rescue)
        render_optional_error_file response_code_for_rescue(exception)
      else
        case exception
        when RoutingError, UnknownAction
          render_text(IO.read(File.join(PUBLIC_ROOT, '404.html')), "404 Not Found")
        else
          render_text(IO.read(File.join(PUBLIC_ROOT, '500.html')), "500 Internal Error")
        end
      end
    end
  end

  module JRuby::Rack
    SESSION_OPTIONS = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
  end
else
  module ActionController
    class Base
      class << self
        attr_accessor :page_cache_directory, :session_store
      end
    end
  end

  module ActionView
    class Base
      class << self
        attr_accessor :cache_template_loading
      end
    end
    module Helpers
      module AssetTagHelper
        ASSETS_DIR = "public" unless defined?(ASSETS_DIR)
        JAVASCRIPTS_DIR = "#{ASSETS_DIR}/javascripts" unless defined?(JAVASCRIPTS_DIR)
        STYLESHEETS_DIR = "#{ASSETS_DIR}/stylesheets" unless defined?(STYLESHEETS_DIR)
      end
    end
  end
  
  module JRuby::Rack
    SESSION_OPTIONS = {}
  end
end