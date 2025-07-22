#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/session/abstract/id' unless defined?(::Rack::Session::Abstract::Persisted)

module JRuby::Rack
  module Session

    class SessionHash < ::Rack::Session::Abstract::SessionHash

      def enabled? # Rails 7.0 added a need for this in Sessions, and forgot to make it optional within flash middleware
        true
      end

      # Allows direct delegation to servlet session methods when session is active
      def method_missing(method, *args, &block)
        servlet_session = @store.get_servlet_session(@req.env)
        if servlet_session && servlet_session.respond_to?(method)
          servlet_session.send(method, *args, &block)
        else
          super
        end
      end
    end

    # Rack based SessionStore implementation but compatible with (older) AbstractStore.
    class SessionStore < ::Rack::Session::Abstract::Persisted

      ENV_SERVLET_SESSION_KEY = 'java.servlet_session'.freeze
      RAILS_SESSION_KEY = "__current_rails_session".freeze

      def initialize(app, options={})
        super(app, options.merge!(:cookie_only => false, :defer => true))
      end

      # (public) servlet specific methods :

      def get_servlet_session(env, create = false)
        servlet_session = env[ENV_SERVLET_SESSION_KEY]
        invalid = false
        begin
          if servlet_session.nil? ||
              ( create && ( invalid || servlet_session.getCreationTime.nil? ) )
            unless servlet_request = env['java.servlet_request']
              raise "JavaServletStore expects a servlet request at env['java.servlet_request']"
            end
            servlet_session =
              begin
                servlet_request.getSession(create)
              rescue java.lang.IllegalStateException => e
                raise "Failed to obtain session due to IllegalStateException: #{e.message}"
              end
            env[ENV_SERVLET_SESSION_KEY] = servlet_session
          end
        rescue java.lang.IllegalStateException # cached session invalidated
          invalid = true; retry # servlet_session.getCreationTime failed ...
        end
        servlet_session
      end

      private # Rack::Session::Abstract::Persisted overrides :

        def session_class
          ::JRuby::Rack::Session::SessionHash
        end

        def initialize_sid
          nil # dummy method - not usable with servlet API
        end

        def generate_sid(secure = @sid_secure)
          nil # dummy method - no session id generation with servlet API
        end

        # Alternative to overriding find_session(req)
        def load_session(req) # session_id arg for get_session alias
          session_id, session = false, {}
          if servlet_session = get_servlet_session(req.env)
            begin
              session_id = servlet_session.getId
              servlet_session.synchronized do
                servlet_session.getAttributeNames.each do |key|
                  if key == RAILS_SESSION_KEY
                    marshalled_bytes = servlet_session.getAttribute(RAILS_SESSION_KEY)
                    if marshalled_bytes
                      data = Marshal.load(String.from_java_bytes(marshalled_bytes))
                      session.update data if Hash === data
                    end
                  else
                    session[key] = servlet_session.getAttribute key
                  end
                end
              end
            rescue java.lang.IllegalStateException # session invalid
              session_id = nil
            end
          end
          [ session_id, session ]
        end

        def extract_session_id(req)
          servlet_session = get_servlet_session(req.env)
          servlet_session.getId rescue nil if servlet_session
        end

        def session_exists?(req)
          value = current_session_id(req)
          value && ! value.empty?
        end

        def loaded_session?(session)
          ! session.is_a?(::JRuby::Rack::Session::SessionHash) || session.loaded?
        end

        # Overridden from Rack, removing support for deferral and unnecessary cookie support when using Java Servlet sessions.
        def commit_session(req, _res)
          session = req.get_header ::Rack::RACK_SESSION
          options = session.options

          if options[:drop] || options[:renew]
            delete_session(req, session.id, options)
          end

          return if options[:drop] || options[:skip]

          if loaded_session?(session)
            # Mirror behaviour of Rails ActionDispatch::Session::AbstractStore#commit_session for Rails 7.1+ compatibility
            commit_csrf_token(req, session)

            session_id ||= session.id
            session_data = session.to_hash.delete_if { |k, v| v.nil? }

            unless write_session(req, session_id, session_data, options)
              req.get_header(::Rack::RACK_ERRORS).puts("Warning! #{self.class.name} failed to save session. Content dropped.")
            end
          end
        end

        def commit_csrf_token(req, session_hash)
          csrf_token = req.env[::ActionController::RequestForgeryProtection::CSRF_TOKEN] if defined?(::ActionController::RequestForgeryProtection::CSRF_TOKEN)
          session_hash[:_csrf_token] = csrf_token if csrf_token
        end

        def write_session(req, session_id, session_hash, _options)
          if session_id.nil? && session_hash.empty?
            delete_session(req)
            return true
          end

          if servlet_session = get_servlet_session(req.env, true)
            begin
              servlet_session.synchronized do
                keys = servlet_session.getAttributeNames
                keys.select { |key| ! session_hash.has_key?(key) }.each do |key|
                  servlet_session.removeAttribute(key)
                end
                session_hash.delete_if do |key,value|
                  if String === key
                    case value
                    when String, Numeric, true, false, nil
                      servlet_session.setAttribute key, value
                      true
                    else
                      if value.respond_to?(:java_object)
                        servlet_session.setAttribute key, value
                        true
                      else
                        false
                      end
                    end
                  end
                end
                if ! session_hash.empty?
                  marshalled_string = Marshal.dump(session_hash)
                  marshalled_bytes = marshalled_string.to_java_bytes
                  servlet_session.setAttribute(RAILS_SESSION_KEY, marshalled_bytes)
                elsif servlet_session.getAttribute(RAILS_SESSION_KEY)
                  servlet_session.removeAttribute(RAILS_SESSION_KEY)
                end
              end
              return true
            rescue java.lang.IllegalStateException # session invalid
              return false
            end
          else
            return false
          end
        end

        def delete_session(req, _session_id = nil, _options = nil)
          # session_id and options arg defaults for delete alias
          (session = get_servlet_session(req.env)) && session.synchronized { session.invalidate }
        rescue java.lang.IllegalStateException # if session already invalid
          nil
        end

    end

  end
end
