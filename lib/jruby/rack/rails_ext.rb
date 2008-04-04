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
  module JRuby::Rack
    SESSION_OPTIONS = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
  end
else
  module JRuby::Rack
    SESSION_OPTIONS = {}
  end
end