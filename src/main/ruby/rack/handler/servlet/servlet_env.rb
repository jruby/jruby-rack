#--
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
                store_parameter(key, get_vals, query_hash)
                store_parameter(key, post_vals, form_hash)
              else
                store_parameter(key, val, query_hash)
              end
            else # POST param :
              store_parameter(key, val, form_hash)
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

        # Store the parameter into the given Hash.
        # By default this is performed in a Rack compatible way and thus
        # some parameter values might get "lost" - it only accepts multiple
        # values for a paramater if it ends with '[]'.
        #
        # @param key the param name
        # @param val the value(s) in a array-like structure
        # @param hash the Hash to store the name, value pair
        def store_parameter(key, val, hash)
          # Rack::Utils.parse_nested_query behaviour
          # for 'foo=bad&foo=bar' does { 'foo' => 'bar' }
          if key[-2, 2] == '[]' # foo[]=f1&foo[]=f2
            hash[ key[0...-2] ] = val.to_a # String[]
          else
            hash[ key ] = val[ val.length - 1 ] # last
          end
        end

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

      end
    end
  end
end