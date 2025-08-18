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
      # Provides an (alternate) Servlet to Rack environment conversion.
      # Servlet parameters are mapped to Rack::Request parameters (no parsing
      # is expected to be performed on Rack's side) in a Rack compatible way.
      #
      # This is useful in the Servlet body (input stream) has been consumed
      # (previously) by the time it reaches JRuby::Rack (e.g. in a filter).
      # http://docs.oracle.com/javaee/6/api/javax/servlet/ServletRequest.html#getParameter(java.lang.String)
      class ServletEnv < DefaultEnv

        def populate!
          load_parameters
          load_cookies
          super
        end

        protected

        def load_env_key(env, key)
          return unless @servlet_env
          if key == QUERY_STRING || key == FORM_INPUT
            load_parameters; @env.fetch(key, nil)
          elsif key == COOKIE_STRING
            load_cookies; @env.fetch(key, nil)
          else
            super
          end
        end

        # @private
        QUERY_STRING = "rack.request.query_string".freeze
        # @private
        QUERY_HASH = "rack.request.query_hash".freeze
        # @private
        FORM_INPUT = "rack.request.form_input".freeze
        # @private
        FORM_HASH = "rack.request.form_hash".freeze

        # @private
        POST_PARAM_METHODS = [ 'POST', 'PUT', 'DELETE' ].freeze

        # Load parameters into the (Rack) env from the Servlet API.
        # using javax.servlet.http.HttpServletRequest#getParameterMap
        def load_parameters
          get_only = ! POST_PARAM_METHODS.include?( @servlet_env.getMethod )
          # we only need to really do this for POSTs but we'll handle all
          query_hash, form_hash = {}, {}
          # NOTE: HttpServletRequest#getParameterMap behaves differently than
          # Rack - preserves all parameters (at least on Tomcat 6/7) - nothing
          # gets "lost" (like with Rack), most notable differences :
          # - multi values are kept even when they do not end with '[]'
          # - if there's a query param and the same param name is in the (POST)
          #   body, both are kept and present as a multi-value
          @servlet_env.getParameterMap.each do |key, val| # String, String[]
            val = [''] if val.nil? # e.g. buggy Jetty 6
            val = [''] if val.length == 1 && val[0].nil?

            if ( q_vals = query_values(key) ) || get_only
              if q_vals.length != val.length
                # some are GET params some POST params
                post_vals, get_vals = val.to_a, []
                post_vals.delete_if do |v|
                  if q_vals.include?(v)
                    get_vals << v; true
                  end
                end
                store_parameter(query_hash, key, get_vals)
                store_parameter(form_hash, key, post_vals)
              else
                store_parameter(query_hash, key, val)
              end
            else # POST param :
              store_parameter(form_hash, key, val)
            end
          end
          # Rack::Request#GET
          @env[ QUERY_STRING ] = query_string
          @env[ QUERY_HASH ] = query_hash
          # Rack::Request#POST
          # TODO should recreate the input e.g. multipart/form-data ...
          @env[ FORM_INPUT ] = @env['rack.input']
          @env[ FORM_HASH ] = form_hash
        end

        def [](key)
          if key.eql? QUERY_HASH
            raise @parameter_error if @parameter_error ||= nil
          end
          super(key)
        end
        public :[]

        # @private
        KEY_SEP = /([^\[\]]+)(?:\[(.*)\])?/

        # Store the parameter into the given Hash.
        # By default this is performed in a Rack compatible way and thus
        # some parameter values might get "lost" - it only accepts multiple
        # values for a paramater if it ends with '[]'.
        #
        # @param key the param name
        # @param val the value(s) in a array-like structure
        # @param params the Hash to store the name, value pair
        def store_parameter2(params, key, val, depth = 0)
          # emulating Rack::Utils.parse_nested_query behavior
          raise ::Rack::Utils::ParamsTooDeepError if depth >= 32

          if match = key.match(KEY_SEP)
            n_key = match[1]; sub = match[2]
          else
            n_key = key; sub = nil # normalized-key[ sub-key ]
          end

          if sub
            if sub.empty? # e.g. foo[]=1&foo[]=2
              if arr = params[ n_key ]
                return mark_parameter_error "expected Array (got #{arr.class}) for param `#{n_key}'" unless arr.is_a?(Array)
                params[ n_key ] = arr + val.to_a; return
              end
              params[ n_key ] = val.to_a # String[]
            else # foo[bar]=rrr&foo[baz]=zzz
              if hsh = params[ n_key ]
                return mark_parameter_error "expected Hash (got #{hsh.class}) for param `#{n_key}'" unless hsh.is_a?(Hash)
                store_parameter2(hsh, sub, val, depth + 1)
              else
                params[ n_key ] = { sub => val[ val.length - 1 ] }
              end
            end
          else
            # for 'foo=bad&foo=bar' does { 'foo' => 'bar' }
            params[ n_key ] = val[ val.length - 1 ] # last
          end
        end

        def store_parameter3(params, key, val, depth = 0)
          raise ::Rack::Utils::ParamsTooDeepError if depth >= 32

          if !key
            # nil name, treat same as empty string (required by tests)
            n_key = after = ''
          elsif depth == 0
            # Start of parsing, don't treat [] or [ at start of string specially
            if start = key.index('[', 1)
              # Start of parameter nesting, use part before brackets as key
              n_key = key[0, start]
              after = key[start, key.length]
            else
              # Plain parameter with no nesting
              n_key = key
              after = ''
            end
          elsif key.start_with?('[]')
            # Array nesting
            n_key = '[]'
            after = key[2, key.length]
          elsif key.start_with?('[') && (start = key.index(']', 1))
            # Hash nesting, use the part inside brackets as the key
            n_key = key[1, start-1]
            after = key[start+1, key.length]
          else
            # Probably malformed input, nested but not starting with [
            # treat full name as key for backwards compatibility.
            n_key = key
            after = ''
          end

          return if n_key.empty?

          if after == ''
            if n_key == '[]' && depth != 0
              return [val]
            else
              params[n_key] = val
            end
          elsif after == "["
            params[key] = val
          elsif after == "[]"
            params[n_key] ||= []
            return mark_parameter_error "expected Array (got #{params[n_key].class.name}) for param `#{n_key}'" unless params[n_key].is_a?(Array)
            params[n_key] << val
          elsif after.start_with?('[]')
            # Recognize x[][y] (hash inside array) parameters
            unless after[2] == '[' && after.end_with?(']') && (child_key = after[3, after.length-4]) && !child_key.empty? && !child_key.index('[') && !child_key.index(']')
              # Handle other nested array parameters
              child_key = after[2, after.length]
            end
            params[n_key] ||= []
            return mark_parameter_error "expected Array (got #{params[n_key].class.name}) for param `#{n_key}'" unless params[n_key].is_a?(Array)

            if params[n_key].last.is_a?(Hash) && !params_hash_has_key?(params[n_key].last, child_key)
              store_parameter3(params[n_key].last, child_key, val, depth + 1)
            else
              params[n_key] << store_parameter3({ }, child_key, val, depth + 1)
            end
          else
            params[n_key] ||= {}
            return mark_parameter_error "expected Hash (got #{params[n_key].class.name}) for param `#{n_key}'" unless params[n_key].is_a?(Hash)
            params[n_key] = store_parameter3(params[n_key], after, val, depth + 1)
          end

          params
        end

        def params_hash_has_key?(hash, key)
          return false if /\[\]/.match?(key)

          key.split(/[\[\]]+/).inject(hash) do |h, part|
            next h if part == ''
            return false unless h.is_a?(Hash) && h.key?(part)
            h[part]
          end

          true
        end

        alias_method :store_parameter, (Rack.release >= '3' ? :store_parameter3 : :store_parameter2)

        COOKIE_STRING = "rack.request.cookie_string".freeze
        COOKIE_HASH = "rack.request.cookie_hash".freeze

        # Load cookies into the (Rack) env from the Servlet API.
        # using javax.servlet.http.HttpServletRequest#getCookies
        def load_cookies
          cookie_hash = {}
          (@servlet_env.getCookies || []).each do |cookie|
            name = cookie.name
            if cookie_hash[name]
              # NOTE: Rack compatible only accepting a single value
              # assume cookies where already ordered - use cookie
            else
              cookie_hash[name] = cookie.value
            end
          end
          # Rack::Request#cookies
          @env[ COOKIE_STRING ] = ( @env['HTTP_COOKIE'] ||= '' )
          @env[ COOKIE_HASH ] = cookie_hash
        end

        private

        def query_string
          @query_string ||= @servlet_env.getQueryString.to_s
        end

        def query_values(key)
          # Rack::Utils.parse_nested_query does not return all values for a multi-key
          # HttpUtils.parseQueryString although deprecated does what we need here :
          # handles multiple values sent by the query string as a string array ...
          ( @query_string_table ||= parse_query_string )[key]
        end

        def parse_query_string
          Java::JavaxServletHttp::HttpUtils.parseQueryString(query_string)
        end

        def mark_parameter_error(msg)
          raise Rack::Utils::ParameterTypeError, msg
        rescue Rack::Utils::ParameterTypeError => e
          @parameter_error = e
        end

      end
    end
  end
end