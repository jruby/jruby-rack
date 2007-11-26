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

module Rack
  module Handler
    class Servlet
      class Result
        include org.jruby.rack.RackResult
        def initialize(result)
          @status, @headers, @body = *result
        end

        def writeStatus(response)
          response.setStatus(@status.to_i)
        end

        def writeHeaders(response)
          @headers.each do |k,v|
            case k
            when /^Content-Type$/i
              response.setContentType(v.to_s)
            when /^Content-Length$/i
              response.setContentLength(v.to_i)
            else
              response.setHeader(k.to_s, v.to_s)
            end
          end
        end

        def writeBody(response)
          stream = response.getOutputStream
          @body.each do |el|
            stream.print(el)
          end
        end
      end

      def initialize(rack_app)
        @rack_app = rack_app
      end

      def call(servlet_env)
        env = env_hash
        add_input_errors_scheme(servlet_env, env)
        add_variables(servlet_env, env)
        add_headers(servlet_env, env)
        Result.new(@rack_app.call(env))
      end
     
      def env_hash
        { "rack.version" => Rack::VERSION, "rack.multithread" => true,
          "rack.multiprocess" => false, "rack.run_once" => false }
      end

      def add_input_errors_scheme(servlet_env, env)
        env['rack.input'] = servlet_env.to_io
        env['rack.errors'] = $stderr
        env['rack.url_scheme'] = servlet_env.getScheme
      end

      def add_variables(servlet_env, env)
        env["REQUEST_METHOD"] = servlet_env.getMethod
        env["REQUEST_METHOD"] ||= "GET"
        env["SCRIPT_NAME"] = servlet_env.getServletPath
        env["SCRIPT_NAME"] ||= ""
        env["PATH_INFO"] = servlet_env.getPathInfo
        env["PATH_INFO"] ||= ""
        env["QUERY_STRING"] = servlet_env.getQueryString
        env["QUERY_STRING"] ||= ""
        env["SERVER_NAME"] = servlet_env.getServerName
        env["SERVER_NAME"] ||= ""
        env["SERVER_PORT"] = servlet_env.getServerPort.to_s
      end

      def add_headers(servlet_env, env)
        env["CONTENT_TYPE"] = servlet_env.getContentType
        env.delete("CONTENT_TYPE") unless env["CONTENT_TYPE"]
        env["CONTENT_LENGTH"] = servlet_env.getContentLength.to_s
        env.delete("CONTENT_LENGTH") unless env["CONTENT_LENGTH"] && env["CONTENT_LENGTH"].to_i >= 0
        servlet_env.getHeaderNames.each do |h|
          next if h =~ /^Content-(Type|Length)$/i
          env["HTTP_#{h.upcase.sub(/-/, '_')}"] = servlet_env.getHeader(h)
        end
      end
    end
  end
end
