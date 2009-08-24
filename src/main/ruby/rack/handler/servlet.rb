#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'
require 'jruby/rack/version'

module Rack
  module Handler
    class Servlet
      def initialize(rack_app)
        @rack_app = rack_app
      end

      def call(servlet_env)
        JRuby::Rack::Response.new(@rack_app.call(create_env(servlet_env)))
      end

      def create_env(servlet_env)
        Env.new(servlet_env).to_hash
      end

      def create_lazy_env(servlet_env)
        LazyEnv.new(servlet_env).to_hash
      end
    end

    class Env
      BUILTINS = %w(rack.version rack.multithread rack.multiprocess rack.run_once
        rack.input rack.errors rack.url_scheme java.servlet_request java.servlet_context
        jruby.rack.version jruby.rack.jruby.version jruby.rack.rack.release)

      REQUEST = %w(CONTENT_TYPE CONTENT_LENGTH REQUEST_METHOD SCRIPT_NAME REQUEST_URI
        PATH_INFO QUERY_STRING SERVER_NAME REMOTE_HOST REMOTE_ADDR REMOTE_USER SERVER_PORT)

      def initialize(servlet_env)
        @env = populate(LazyEnv.new(servlet_env).to_hash)
      end

      def populate(lazy_hash)
        hash = {}
        (BUILTINS + REQUEST).each {|k| lazy_hash[k]} # load builtins and request vars
        lazy_hash['HTTP_'] # load headers
        lazy_hash.keys.each {|k| hash[k] = lazy_hash[k]}
        hash
      end

      def to_hash
        @env
      end
    end

    class LazyEnv
      def initialize(servlet_env)
        @env = Hash.new {|h,k| load_env_key(h,k)}
        @servlet_env = servlet_env
        load_servlet_request_attributes
      end

      def to_hash
        @env
      end

      def load_env_key(env, key)
        if respond_to?("load__#{key}")
          send("load__#{key}", env)
        elsif key =~ /^(rack|java|jruby)/
          load_builtin(env, key)
        elsif key =~ /^HTTP_/
          load_headers(env, key)
        end
      end

      def load_servlet_request_attributes
        @servlet_env.getAttributeNames.each do |k|
          v = @servlet_env.getAttribute(k)
          case k
          when "SERVER_PORT", "CONTENT_LENGTH"
            @env[k] = v.to_s if v.to_i >= 0
          when "CONTENT_TYPE"
            @env[k] = v if v
          else
            if v
              @env[k] = v
            else
              @env[k] = ""
            end
          end
        end
      end

      def load_headers(env, key)
        unless @headers_added
          @headers_added = true
          @servlet_env.getHeaderNames.each do |h|
            next if h =~ /^Content-(Type|Length)$/i
            k = "HTTP_#{h.upcase.gsub(/-/, '_')}"
            env[k] = @servlet_env.getHeader(h) unless env.has_key?(k)
          end
        end
        if env.has_key?(key)
          env[key]
        else
          nil
        end
      end

      def load_builtin(env, key)
        case key
        when 'rack.version'         then env[key] = ::Rack::VERSION
        when 'rack.multithread'     then env[key] = true
        when 'rack.multiprocess'    then env[key] = false
        when 'rack.run_once'        then env[key] = false
        when 'rack.input'           then env[key] = @servlet_env.to_io
        when 'rack.errors'          then env[key] = JRuby::Rack::ServletLog.new
        when 'rack.url_scheme'      then env[key] = @servlet_env.getScheme
        when 'java.servlet_request' then env[key] = @servlet_env.getRequest rescue @servlet_env
        when 'java.servlet_context' then env[key] = $servlet_context
        when 'jruby.rack.version'   then env[key] = JRuby::Rack::VERSION
        when 'jruby.rack.jruby.version' then env[key] = JRUBY_VERSION
        when 'jruby.rack.rack.release'  then env[key] = ::Rack.release
        else
          nil
        end
      end

      def load__CONTENT_TYPE(env)
        content_type = @servlet_env.getContentType
        env["CONTENT_TYPE"] = content_type if content_type
      end

      def load__CONTENT_LENGTH(env)
        content_length = @servlet_env.getContentLength
        env["CONTENT_LENGTH"] = content_length.to_s if content_length >= 0
      end

      def load__REQUEST_METHOD(env)
        env["REQUEST_METHOD"] = @servlet_env.getMethod || "GET"
      end

      def load__SCRIPT_NAME(env)
        env["SCRIPT_NAME"] = @servlet_env.getScriptName
      end

      def load__REQUEST_URI(env)
        env["REQUEST_URI"] = @servlet_env.getRequestURI
      end

      def load__PATH_INFO(env)
        env["PATH_INFO"] = @servlet_env.getPathInfo
      end

      def load__QUERY_STRING(env)
        env["QUERY_STRING"] = @servlet_env.getQueryString || ""
      end

      def load__SERVER_NAME(env)
        env["SERVER_NAME"] = @servlet_env.getServerName || ""
      end

      def load__REMOTE_HOST(env)
        env["REMOTE_HOST"] = @servlet_env.getRemoteHost || ""
      end

      def load__REMOTE_ADDR(env)
        env["REMOTE_ADDR"] = @servlet_env.getRemoteAddr || ""
      end

      def load__REMOTE_USER(env)
        env["REMOTE_USER"] = @servlet_env.getRemoteUser || ""
      end

      def load__SERVER_PORT(env)
        env["SERVER_PORT"] = @servlet_env.getServerPort.to_s
      end
    end
  end
end
