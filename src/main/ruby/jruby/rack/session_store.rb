#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/session/abstract/id' unless defined?(::Rack::Session::Abstract::ID)

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
    class SessionStore < ::Rack::Session::Abstract::ID

      ENV_SERVLET_SESSION_KEY = 'java.servlet_session'.freeze
      RAILS_SESSION_KEY = "__current_rails_session".freeze

      def initialize(app, options={})
        super(app, options.merge!(:cookie_only => false, :defer => true))
      end

      def context(env, app = @app)
        req = make_request env
        prepare_session(req)
        status, headers, body = app.call(req.env)
        commit_session(req, status, headers, body)
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

      private # Rack::Session::Abstract::ID overrides :

        def session_class; ::JRuby::Rack::Session::SessionHash; end # Rack 1.5

        def initialize_sid
          nil # dummy method - not usable with servlet API
        end

        def generate_sid(secure = @sid_secure)
          nil # dummy method - no session id generation with servlet API
        end

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

        def commit_session(req, status, headers, body)
          session = req.env[::Rack::RACK_SESSION]
          options = req.env[::Rack::RACK_SESSION_OPTIONS]

          if options[:drop] || options[:renew]
            destroy_session(req.env, options[:id], options)
          end

          return [status, headers, body] if options[:drop] || options[:skip]

          if loaded_session?(session)
            session_id = session.respond_to?(:id=) ? session.id : options[:id]
            session_data = session.to_hash.delete_if { |_,v| v.nil? }
            unless set_session(req.env, session_id, session_data, options)
              req.env["rack.errors"].puts("WARNING #{self.class.name} failed to save session. Content dropped.")
            end
          end

          [status, headers, body]
        end

        def set_session(env, session_id, hash, options)
          if session_id.nil? && hash.empty?
            destroy_session(env)
            return true
          end
          if servlet_session = get_servlet_session(env, true)
            begin
              servlet_session.synchronized do
                keys = servlet_session.getAttributeNames
                keys.select { |key| ! hash.has_key?(key) }.each do |key|
                  servlet_session.removeAttribute(key)
                end
                hash.delete_if do |key,value|
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
                if ! hash.empty?
                  marshalled_string = Marshal.dump(hash)
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

        def destroy_session(env, session_id = nil, options = nil)
          # session_id and options arg defaults for destory alias
          (session = get_servlet_session(env)) && session.synchronized { session.invalidate }
        rescue java.lang.IllegalStateException # if session already invalid
          nil
        end

    end

  end
end
