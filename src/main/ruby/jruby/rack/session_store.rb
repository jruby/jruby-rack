#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# as of rails 3.1.x the rack session hash implementation is used
# rather than the custom rails AbstractStore::SessionHash class
require 'rack/session/abstract/id' unless defined? Rack::Session::Abstract::ID

module JRuby::Rack::Session

  class SessionHash < Rack::Session::Abstract::SessionHash

    def initialize(by, env)
      super(by, env)
    end

    def finish_save()
      if @loaded || !@env[Rack::Session::Abstract::ENV_SESSION_KEY].equal?(self)
        unless @env[Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY][:id].nil?
          @by.save_session(@env, self.to_hash)
        else
          @by.close_session(@env)
        end
      end
    end

    # Allows direct delegation to servlet session methods when session is active
    def method_missing(meth, *args, &block)
      servlet_session = @by.get_servlet_session(@env)
      if servlet_session && servlet_session.respond_to?(meth)
        servlet_session.send(meth, *args, &block)
      else
        super
      end
    end

  end

  class SessionStore < Rack::Session::Abstract::ID

    RAILS_SESSION_KEY = "__current_rails_session"

    def initialize(app, options={})
      super(app, options.merge!(:cookie_only => false, :defer => true))
    end

    def get_servlet_session(env, create = false)
      env['java.servlet_session'] = env['java.servlet_request'].getSession(create) unless env['java.servlet_session']
      env['java.servlet_session']
    end

    def save_session(env, data)
      set_session(env, nil, data, self.default_options)
    end

    def close_session(env)
      (session = get_servlet_session(env)) and session.invalidate
    rescue => exception
      nil
    end

    private

    def prepare_session(env)
      raise "JavaServletStore should only be used with JRuby-Rack" unless env['java.servlet_request']
      super(env)
      existing = env[Rack::Session::Abstract::ENV_SESSION_KEY]
      env[Rack::Session::Abstract::ENV_SESSION_KEY] = SessionHash.new(self, env)
      env[Rack::Session::Abstract::ENV_SESSION_KEY].merge! existing if existing
    end

    def extract_session_id(env)
      servlet_session = get_servlet_session(env)
      servlet_session.getId if servlet_session
    end

    def load_session(env)
      session_id, session = false, {}
      if servlet_session = get_servlet_session(env)
        session_id = servlet_session.getId
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
      [session_id, session]
    end

    def set_session(env, session_id, hash, options)
      if servlet_session = get_servlet_session(env, true)
        servlet_session.getAttributeNames.select {|key| !hash.has_key?(key)}.each do |key|
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
        if !hash.empty?
          marshalled_string = Marshal.dump(hash)
          marshalled_bytes = marshalled_string.to_java_bytes
          servlet_session.setAttribute(RAILS_SESSION_KEY, marshalled_bytes)
        elsif servlet_session.getAttribute(RAILS_SESSION_KEY)
          servlet_session.removeAttribute(RAILS_SESSION_KEY)
        end
        true
      else
        false
      end
    end

    def destroy_session(env, session_id, options)
      close_session(env)
    end

  end

end
