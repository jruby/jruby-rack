#--
# **** BEGIN LICENSE BLOCK *****
# Version: CPL 1.0/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Common Public
# License Version 1.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.eclipse.org/legal/cpl-v10.html
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# Copyright (C) 2007 Sun Microsystems, Inc.
#
# Alternatively, the contents of this file may be used under the terms of
# either of the GNU General Public License Version 2 or later (the "GPL"),
# or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
# in which case the provisions of the GPL or the LGPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of either the GPL or the LGPL, and not to allow others to
# use your version of this file under the terms of the CPL, indicate your
# decision by deleting the provisions above and replace them with the notice
# and other provisions required by the GPL or the LGPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the CPL, the GPL or the LGPL.
# **** END LICENSE BLOCK ****
#++

require 'cgi/session/java_servlet_store'
        
module Rack
  module Adapter
    ServletContext = $servlet_context
    class RailsServletHelper
      attr_reader :rails_env, :rails_root, :public_root

      def initialize(servlet_context = nil)
        @servlet_context = servlet_context || ServletContext
        @rails_root = @servlet_context.getInitParameter 'rails.root'
        @rails_root ||= '/WEB-INF'
        @rails_root = @servlet_context.getRealPath @rails_root
        @rails_env = @servlet_context.getInitParameter 'rails.env'
        @rails_env ||= 'production'
        @public_root = @servlet_context.getInitParameter 'public.root'
        @public_root ||= '/WEB-INF/public'
        @public_root = @servlet_context.getRealPath @public_root
      end
      
      def logdev
        unless @logdev
          @logdev = Proc.new {|msg| @servlet_context.log msg }
          def @logdev.write(msg); call(msg); end
          def @logdev.close; end
        end
        @logdev
      end

      def logger
        require 'logger'
        Logger.new(logdev)
      end

      def setup_sessions
        if default_sessions?
          session_options[:database_manager] = CGI::Session::JavaServletStore
        end
        # Turn off default cookies when using Java sessions
        if java_sessions?
          session_options[:no_cookies] = true
        end
      end

      def session_options
        ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS
      end

      def session_options_for_request(env)
        options = session_options.dup
        options[:java_servlet_request] = env['java.servlet_request'] if java_sessions?
        options
      end
      
      def java_sessions?
        session_options[:database_manager] == CGI::Session::JavaServletStore
      end

      def default_sessions?
        session_options[:database_manager] == CGI::Session::PStore
      end

      def self.instance
        @instance ||= self.new
      end
    end

    class StaticFiles
      def initialize(app, root)
        @app = app
        @file_server = Rack::File.new(root)
      end

      def call(env)
        if env["PATH_INFO"] =~ %r{/$}
          file_env = env.dup
          file_env["PATH_INFO"] = env["PATH_INFO"] + 'index.html'
        else
          file_env = env
        end

        result = @file_server.call(file_env)
        if result[0] == 404
          @app.call(env) 
        else
          result
        end
      end
    end

    class RailsSessions
      def initialize(app, servlet_helper)
        @app = app
        @servlet_helper = servlet_helper
      end

      def call(env)
        env['rails.session_options'] = @servlet_helper.session_options_for_request(env)
        @app.call(env)
      end
    end
  end
end