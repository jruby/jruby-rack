#--
# Copyright (c) 2012-2016 Karol Bucek, LTD.
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/handler/servlet'
require 'rack' # Rack.release is needed at class definition time - this file
# is auto-loaded on first use, which is after the application boot loads rack

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
          query_params, form_params = query_parser.make_params, query_parser.make_params
          # NOTE: HttpServletRequest#getParameterMap merges query-string and
          # (POST) body parameters and exposes *every* raw value per name -
          # including repeated names that do not end with '[]' and names that
          # appear in both the query string and the body. We rely on that
          # completeness only to reconstruct which values came from the query
          # string vs the body (see the length comparison below), so GET and
          # POST each end up matching what Rack would have parsed. The values
          # themselves are still normalized by Rack (#normalize_params) - i.e.
          # repeated non-'[]' names collapse to the last value, '[]' yields an
          # Array, etc. - so the resulting params are not "multi-valued" here.
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
                store_parameter(query_params, key, get_vals)
                store_parameter(form_params, key, post_vals)
              else
                store_parameter(query_params, key, val)
              end
            else # POST param :
              store_parameter(form_params, key, val)
            end
          end
          # Rack::Request#GET
          @env[ QUERY_STRING ] = query_string
          @env[ QUERY_HASH ] = query_params.to_h
          # Rack::Request#POST
          # TODO should recreate the input e.g. multipart/form-data ...
          @env[ FORM_INPUT ] = @env['rack.input']
          @env[ FORM_HASH ] = form_params.to_h
        end

        def [](key)
          if key.eql? QUERY_HASH
            raise @parameter_error if @parameter_error ||= nil
          end
          super(key)
        end
        public :[]

        # Store the servlet parameter values under the given (raw) name into the
        # Rack params, reusing Rack's own QueryParser#normalize_params
        #
        # Servlet parameter values arrive already split into an Array (unlike
        # Rack which sees each name=value pair separately) so the values are
        # replayed one by one; a ParameterTypeError aborts the offending name
        # and is re-raised lazily on QUERY_HASH access (see #[]).
        #
        # @param params the (Rack::QueryParser::Params) accumulator
        # @param key the (raw) param name, possibly with `[]`/`[nested]` syntax
        # @param val the value(s) in an array-like structure
        def store_parameter(params, key, val)
          val.each { |v| query_parser.normalize_params(params, key, v, query_parser.param_depth_limit) }
        rescue ::Rack::Utils::ParameterTypeError => e
          @parameter_error = e
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

        # The Rack query parser used for both building the params accumulators
        # (#make_params) and nesting each value (#normalize_params). Rack's
        # default parser is a memoized singleton, so this is cheap to call.
        def query_parser
          ::Rack::Utils.default_query_parser
        end

        def query_string
          @query_string ||= @servlet_env.getQueryString.to_s
        end

        def query_values(key)
          # returns all query-string values for a (possibly repeated) param
          # name as an Array, or nil when the name is not in the query string
          ( @query_string_table ||= parse_query_string )[key]
        end

        def parse_query_string
          # Rack::Utils.parse_query yields a String for single and an Array for
          # repeated names - normalize to always-Array for query_values' callers
          ::Rack::Utils.parse_query(query_string, '&').each_with_object({}) do |(key, value), table|
            table[key] = value.is_a?(Array) ? value : [ value ]
          end
        end

      end
    end
  end
end