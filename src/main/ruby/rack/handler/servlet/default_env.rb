#--
# Copyright (c) 2012-2016 Karol Bucek, LTD.
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/handler/servlet'

module Rack
  module Handler
    class Servlet
      # Provides a (default) Servlet to Rack environment conversion.
      # Rack builtin requirements, CGI variables and HTTP headers are to be
      # filled from the Servlet API.
      # Parameter parsing is left to be done by Rack::Request itself (e.g. by
      # consuming the request body in case of a POST), thus this expects the
      # ServletRequest input stream to be not read (e.g. for POSTs).
      class DefaultEnv < Hash # The environment must be an instance of Hash !

        BUILTINS = %w(rack.version rack.input rack.errors rack.url_scheme
          rack.multithread rack.multiprocess rack.run_once rack.hijack?
          java.servlet_request java.servlet_response java.servlet_context
          jruby.rack.version).
          map!(&:freeze)

        VARIABLES = %w(CONTENT_TYPE CONTENT_LENGTH PATH_INFO QUERY_STRING
          REMOTE_ADDR REMOTE_HOST REMOTE_USER REQUEST_METHOD REQUEST_URI
          SCRIPT_NAME SERVER_NAME SERVER_PORT SERVER_SOFTWARE).
          map!(&:freeze)

        attr_reader :env

        # Factory method for creating the Hash.
        # Besides initializing a new env instance this method by default
        # eagerly populates (and returns) the env Hash.
        #
        # Subclasses might decide to change this behavior by overriding
        # this method (NOTE: that #initialize returns a lazy instance).
        #
        # However keep in mind that some Rack middleware or extension might
        # dislike a lazy env since it does not reflect env.keys "correctly".
        def self.create(servlet_env)
          raise ArgumentError, "nil servlet_env" if servlet_env.nil?
          self.new(servlet_env).populate
        end

        # Initialize this (Rack) environment from the servlet environment.
        #
        # The returned instance is lazy as much as possible (the env hash
        # returned from #to_hash will be filled on demand), one can use
        # #populate to fill in the env keys eagerly.
        def initialize(servlet_env = nil)
          super()
          # NOTE: due AS Hash extensions we shall support `self.class.new`
          # happens e.g. during `env.slice(*keys)` in rescue .erb template
          unless servlet_env.nil?
            @servlet_env = servlet_env; @env = self
            # always pre-load since they might override variables
            load_attributes
          end
        end

        # If a block is given, it yields to the block if the value hasn't been set
        # on the request.
        def fetch_header(name, &block)
          @env.fetch(name, &block)
        end

        def get_header(key)
          @env[key]
        end

        def populate
          unless @populated ||= false
            populate! if @servlet_env
            @populated = true
          end
          self
        end

        def populate!
          load_builtins
          load_variables
          load_headers
          self
        end

        def session_options
          fetch_header(RACK_SESSION_OPTIONS) do |k|
            set_header RACK_SESSION_OPTIONS, {}
          end
        end

        def set_header(name, v)
          @env[name] = v
        end

        def to_hash(bare = nil)
          if bare
            {}.update(populate)
          else
            self
          end
        end

        # @private
        DEFAULT = Object.new
        private_constant :DEFAULT rescue nil

        alias_method '_fetch', :fetch; private '_fetch' # Hash#fetch
        def fetch(key, default = DEFAULT, &block)
          default.equal?(DEFAULT) ? _fetch(key, &block) : _fetch(key, default, &block)
        end

        def [](key)
          value = _fetch(key, DEFAULT)
          value.equal?(DEFAULT) ? load_env_key(self, key) : value
        end

        alias_method '_key?', :key?; private '_key?'
        def key?(key)
          _key?(key) || load_env_key(self, key) != nil
        end
        alias_method :has_key?, :key?
        alias_method :include?, :key?
        alias_method :member?, :key?

        def keys; populate; super; end
        def values; populate; super; end

        def each(&block); populate; super;end
        def each_key(&block); populate; super; end
        def each_value(&block); populate; super; end
        def each_pair(&block); populate; super; end

        protected

        def load_attributes
          for name in @servlet_env.getAttributeNames
            value = @servlet_env.getAttribute(name)
            case name
            when 'SERVER_PORT', 'CONTENT_LENGTH'
              @env[name] = value.to_s if value.to_i >= 0
            when 'CONTENT_TYPE'
              @env[name] = value if value
            else
              @env[name] = value
            end
          end
        end

        def load_builtins
          for b in BUILTINS
            load_builtin(@env, b) unless @env.key?(b)
          end
        end

        def load_variables
          for v in VARIABLES
            load_variable(@env, v) unless @env.key?(v)
          end
        end

        @@content_header_names = /^Content-(Type|Length)$/i

        def load_headers
          # NOTE: getHeaderNames and getHeaders might return null !
          # if the container does not allow access to header information
          return unless header_names = @servlet_env.getHeaderNames
          for name in header_names
            next if name =~ @@content_header_names
            key = "HTTP_#{name.upcase.gsub(/-/, '_')}".freeze
            @env[key] = @servlet_env.getHeader(name) unless @env.key?(key)
          end
        end

        def load_env_key(env, key)
          return unless @servlet_env
          if key[0, 5] == 'HTTP_'
            load_header(env, key)
          elsif key =~ /^(rack|java|jruby)/
            load_builtin(env, key)
          else
            load_variable(env, key)
          end
        end

        def load_header(env, key)
          return nil if @servlet_env.nil?
          name = key.sub('HTTP_', '').
            split('_').each { |w| w.downcase!; w.capitalize! }.join('-')
          return if name =~ @@content_header_names
          if header = @servlet_env.getHeader(name)
            env[key] = header # null if it does not have a header of that name
          end
        end

        def load_variable(env, key)
          return nil if @servlet_env.nil?
          case key
            when 'CONTENT_TYPE'
              content_type = @servlet_env.getContentType
              env[key] = content_type if content_type
            when 'CONTENT_LENGTH'
              content_length = @servlet_env.getContentLength
              env[key] = content_length.to_s if content_length >= 0
            when 'PATH_INFO'       then env[key] = @servlet_env.getPathInfo
            when 'QUERY_STRING'    then env[key] = @servlet_env.getQueryString || ''
            when 'REMOTE_ADDR'     then env[key] = @servlet_env.getRemoteAddr || ''
            when 'REMOTE_HOST'     then env[key] = @servlet_env.getRemoteHost || ''
            when 'REMOTE_USER'     then env[key] = @servlet_env.getRemoteUser || ''
            when 'REQUEST_METHOD'  then env[key] = @servlet_env.getMethod || 'GET'
            when 'REQUEST_URI'     then env[key] = @servlet_env.getRequestURI
            when 'SCRIPT_NAME'     then env[key] = @servlet_env.getScriptName
            when 'SERVER_NAME'     then env[key] = @servlet_env.getServerName || ''
            when 'SERVER_PORT'     then env[key] = @servlet_env.getServerPort.to_s
            when 'SERVER_SOFTWARE' then env[key] = rack_context.getServerInfo
            else
              # NOTE: even though we allowed for overrides and loaded all attributes
              # up front (looping thru getAttributeNames) container "hidden" attribs
              # might still get resolved e.g. 'org.apache.tomcat.sendfile.support'
              if hidden_attr = @servlet_env.getAttribute(key)
                env[key] = hidden_attr
              else
                nil
              end
          end
        end

        def load_builtin(env, key)
          case key
          when 'rack.version'          then env[key] = ::Rack::VERSION
          when 'rack.multithread'      then env[key] = true
          when 'rack.multiprocess'     then env[key] = false
          when 'rack.run_once'         then env[key] = false
          when 'rack.hijack?'          then env[key] = false
          when 'rack.input'            then
            env[key] = @servlet_env ? JRuby::Rack::Input.new(@servlet_env) : nil
          when 'rack.errors'           then context = rack_context
            env[key] = context ? JRuby::Rack::ServletLog.new(context) : nil
          when 'rack.url_scheme'
            env[key] = scheme = @servlet_env ? @servlet_env.getScheme : nil
            env['HTTPS'] = 'on' if scheme == 'https'
            scheme
          when 'java.servlet_request'  then env[key] = servlet_request
          when 'java.servlet_response' then env[key] = servlet_response
          when 'java.servlet_context'  then env[key] = @servlet_env.servlet_context
          when 'jruby.rack.context'    then env[key] = rack_context
          when 'jruby.rack.version'    then env[key] = JRuby::Rack::VERSION
          else
            nil
          end
        end

        private

        def rack_context
          return @rack_context || nil unless @rack_context.nil?
          @rack_context =
            if @servlet_env.respond_to?(:context)
              @servlet_env.context # RackEnvironment#getContext()
            else
              JRuby::Rack.context || false # raise("missing rack context")
            end
        end

        def servlet_request
          @servlet_env.respond_to?(:request) ? @servlet_env.request : @servlet_env
        end

        def servlet_response
          @servlet_env.respond_to?(:response) ? @servlet_env.response : @servlet_env
        end

        TRANSIENT_KEYS = [ 'rack.input', 'rack.errors',
          'java.servlet_request', 'java.servlet_response',
          'java.servlet_context', 'jruby.rack.context'
        ]

        def marshal_dump
          hash = to_hash(true)
          for key in TRANSIENT_KEYS
            hash.delete(key)
          end
          hash
        end

        def marshal_load(hash)
          for key, value in hash
            self[key] = value
          end
          @populated = true
          @env = self
        end

      end
    end
  end
end
