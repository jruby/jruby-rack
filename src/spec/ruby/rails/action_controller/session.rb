module ActionController
  module Session
    class AbstractStore
      ENV_SESSION_KEY = 'rack.session'.freeze
      ENV_SESSION_OPTIONS_KEY = 'rack.session.options'.freeze

      class SessionHash < Hash
        def initialize(by, env)
          super()
          @by = by
          @env = env
          @loaded = false
        end

        def [](key)
          load! unless @loaded
          super
        end

        def []=(key, value)
          load! unless @loaded
          super
        end

        def to_hash
          h = {}.replace(self)
          h.delete_if { |k,v| v.nil? }
          h
        end

        private
        def load!
          id, session = @by.send(:load_session, @env)
          (@env[ENV_SESSION_OPTIONS_KEY] ||= {})[:id] = id
          replace(session)
          @loaded = true
        end
      end
    end
  end
end
