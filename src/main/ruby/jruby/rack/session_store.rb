#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/session/abstract/id' unless defined?(::Rack::Session::Abstract::ID)

module JRuby::Rack
  module Session
  
    if defined?(::Rack::Session::Abstract::SessionHash) # Rack 1.3+

      # as of rails 3.1.x the rack session hash implementation is used
      # rather than the custom rails AbstractStore::SessionHash class
      class SessionHash < ::Rack::Session::Abstract::SessionHash; end
      
      # 1.5.0 removed SessionHash http://github.com/rack/rack/commit/83a270d64820
      OptionsHash = ::Rack::Session::Abstract::OptionsHash rescue nil

    elsif defined?(ActionDispatch::Session::AbstractStore) # Rails 3.0
      
      require 'active_support/core_ext/hash' # non-loaded SessionHash dependency
      
      class SessionHash < ActionDispatch::Session::AbstractStore::SessionHash; end
      
      OptionsHash = ActionDispatch::Session::AbstractStore::OptionsHash

    else # a fallback for (old) Rails 2.3

      class SessionHash < ActionController::Session::AbstractStore::SessionHash; end
      
      OptionsHash = ActionController::Session::AbstractStore::OptionsHash

    end

    class SessionHash
      
      # Allows direct delegation to servlet session methods when session is active
      def method_missing(method, *args, &block)
        servlet_session = store.get_servlet_session(@env)
        if servlet_session && servlet_session.respond_to?(method)
          servlet_session.send(method, *args, &block)
        else
          super
        end
      end
      
      private
      def store
        @store ||= defined?(@store) ? @store : @by # Rack 1.5 renamed @by
      end
      
    end
    
    # Rack based SessionStore implementation but compatible with (older) AbstractStore.
    class SessionStore < ::Rack::Session::Abstract::ID

      ENV_SESSION_KEY = defined?(::Rack::Session::Abstract::ENV_SESSION_KEY) ? 
        ::Rack::Session::Abstract::ENV_SESSION_KEY : 'rack.session'.freeze

      ENV_SESSION_OPTIONS_KEY = defined?(::Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY) ? 
        ::Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY : 'rack.session.options'.freeze

      ENV_SERVLET_SESSION_KEY = 'java.servlet_session'.freeze

      RAILS_SESSION_KEY = "__current_rails_session".freeze

      def initialize(app, options={})
        super(app, options.merge!(:cookie_only => false, :defer => true))
      end

      def context(env, app = @app) # adapt Rack 1.1/1.2 to be compatible with 1.3+
        prepare_session(env)
        status, headers, body = app.call(env)
        commit_session(env, status, headers, body)
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
            servlet_session = servlet_request.getSession(create)
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

        def prepare_session(env) # exist since Rack 1.3
          session_was = env[ENV_SESSION_KEY]
          env[ENV_SESSION_KEY] = session_class.new(self, env)
          if options_hash = ::JRuby::Rack::Session::OptionsHash
            env[ENV_SESSION_OPTIONS_KEY] = options_hash.new(self, env, @default_options)
          else
            env[ENV_SESSION_OPTIONS_KEY] = @default_options.dup
          end
          env[ENV_SESSION_KEY].merge! session_was if session_was
        end

        def load_session(env, session_id = nil) # session_id arg for get_session alias
          session_id, session = false, {}
          if servlet_session = get_servlet_session(env)
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
        alias :get_session :load_session # for AbstractStore::SessionHash compatibility

        def extract_session_id(env)
          servlet_session = get_servlet_session(env)
          servlet_session.getId rescue nil if servlet_session
        end
        
        def current_session_id(env)
          env[ENV_SESSION_OPTIONS_KEY][:id] # 1.5.0: env[ENV_SESSION_KEY].id
        end if ::JRuby::Rack::Session::OptionsHash
        
        def session_exists?(env)
          value = current_session_id(env)
          value && ! value.empty?
        end
        alias :exists? :session_exists? # for AbstractStore::SessionHash compatibility
        
        def loaded_session?(session)
          ! session.is_a?(::JRuby::Rack::Session::SessionHash) || session.loaded?
        end
        
        def commit_session(env, status, headers, body)
          session = env[ENV_SESSION_KEY]
          options = env[ENV_SESSION_OPTIONS_KEY]
          
          if options[:drop] || options[:renew]
            destroy_session(env, options[:id], options)
          end
          
          return [status, headers, body] if options[:drop] || options[:skip]
          
          if loaded_session?(session)
            session_id = session.respond_to?(:id=) ? session.id : options[:id]
            session_data = session.to_hash.delete_if { |_,v| v.nil? }
            unless set_session(env, session_id, session_data, options)
              env["rack.errors"].puts("WARNING #{self.class.name} failed to save session. Content dropped.")
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
        alias :destroy :destroy_session # for AbstractStore::SessionHash compatibility
        
    end

  end
end
