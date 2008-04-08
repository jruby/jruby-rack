#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'

module Rack
  module Handler
    class Servlet
      def initialize(rack_app)
        @rack_app = rack_app
      end

      def call(servlet_env)
        env = env_hash
        add_input_errors_scheme(servlet_env, env)
        add_servlet_request_attributes(servlet_env, env)
        add_variables(servlet_env, env)
        add_headers(servlet_env, env)
        JRuby::Rack::Response.new(@rack_app.call(env))
      end
     
      def env_hash
        { "rack.version" => Rack::VERSION, "rack.multithread" => true,
          "rack.multiprocess" => false, "rack.run_once" => false }
      end

      def add_input_errors_scheme(servlet_env, env)
        env['rack.input'] = servlet_env.to_io
        env['rack.errors'] = JRuby::Rack::ServletLog.new
        env['rack.url_scheme'] = servlet_env.getScheme
        env['java.servlet_request'] = servlet_env
        env['java.servlet_context'] = $servlet_context
      end

      def add_servlet_request_attributes(servlet_env, env)
	servlet_env.getAttributeNames.each do |k|
          env[k] = servlet_env.getAttribute(k)
        end
      end

      def add_variables(servlet_env, env)
        context_path = servlet_env.getContextPath || ""
        env["REQUEST_METHOD"] ||= servlet_env.getMethod || "GET"
        env["SCRIPT_NAME"]    ||= "#{context_path}#{servlet_env.getServletPath}"
        env["REQUEST_URI"]    ||= servlet_env.getRequestURI || ""
        path_info = servlet_env.getServletPath || ""
        path_info += servlet_env.getPathInfo if servlet_env.getPathInfo
        env["PATH_INFO"]      ||= path_info
        env["QUERY_STRING"]   ||= servlet_env.getQueryString || ""
        env["SERVER_NAME"]    ||= servlet_env.getServerName || ""
        env["REMOTE_HOST"]    ||= servlet_env.getRemoteHost || ""
        env["REMOTE_ADDR"]    ||= servlet_env.getRemoteAddr || ""
        env["REMOTE_USER"]    ||= servlet_env.getRemoteUser || ""
        env["SERVER_PORT"]    ||= servlet_env.getServerPort
        env["SERVER_PORT"]      = env["SERVER_PORT"].to_s unless String === env["SERVER_PORT"]
      end

      def add_headers(servlet_env, env)
        env["CONTENT_TYPE"] ||= servlet_env.getContentType
        env.delete("CONTENT_TYPE") unless env["CONTENT_TYPE"]
        env["CONTENT_LENGTH"] ||= servlet_env.getContentLength
        env["CONTENT_LENGTH"] = env["CONTENT_LENGTH"].to_s unless String === env["CONTENT_LENGTH"]
        env.delete("CONTENT_LENGTH") unless env["CONTENT_LENGTH"] && env["CONTENT_LENGTH"].to_i >= 0
        servlet_env.getHeaderNames.each do |h|
          next if h =~ /^Content-(Type|Length)$/i
          env["HTTP_#{h.upcase.gsub(/-/, '_')}"] ||= servlet_env.getHeader(h)
        end
      end
    end
  end
end
