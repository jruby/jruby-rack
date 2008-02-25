#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'rack/adapter/servlet_helper'
require 'cgi/session/java_servlet_store'
        
module Rack
  module Adapter
    class RailsServletHelper < ServletHelper
      attr_reader :rails_env, :rails_root

      def initialize(servlet_context = nil)
        super
        @rails_root = @servlet_context.getInitParameter 'rails.root'
        @rails_root ||= '/WEB-INF'
        @rails_root = @servlet_context.getRealPath @rails_root
        @rails_env = @servlet_context.getInitParameter 'rails.env'
        @rails_env ||= 'production'
      end
      
      def setup_sessions
        if default_sessions?
          session_options[:database_manager] = java_servlet_store
        end
        # Turn off default cookies when using Java sessions
        if java_sessions?
          session_options[:no_cookies] = true
        end
      end

      def session_options
        @session_options ||= {} 
      end

      def session_options_for_request(env)
        options = session_options.dup
        options[:java_servlet_request] = env['java.servlet_request'] if java_sessions?
        options
      end
      
      def java_sessions?
        session_options[:database_manager] == java_servlet_store
      end

      def default_sessions?
        session_options[:database_manager] == default_store
      end

      def default_store
	defined?(::CGI::Session::PStore) && CGI::Session::PStore
      end

      def java_servlet_store
	CGI::Session::JavaServletStore
      end
    end

    class RailsSetup
      def initialize(app, servlet_helper)
        @app = app
        @servlet_helper = servlet_helper
      end

      def call(env)
        env['rails.session_options'] = @servlet_helper.session_options_for_request(env)
        env["RAILS_RELATIVE_URL_ROOT"] = env['java.servlet_request'].getContextPath
        @app.call(env)
      end
    end
  end
end