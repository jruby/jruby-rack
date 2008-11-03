require 'merb-core/dispatch/session'

module Merb
  class ServletSession < ::Merb::SessionContainer

    self.session_store_type = :servlet

    class << self
      def setup(request)
        session = self.new(Merb::SessionMixin.rand_uuid, request)
        request.session = session
      end
    end

    def initialize(session_id, request)
      super session_id
      @session_id = session_id
      @java_request = request.env['java.servlet_request']
      self.restore_from_servlet_session
    end

    def restore_from_servlet_session
      java_session = @java_request.getSession(false)
      if java_session
        java_session.getAttributeNames.each do |k|
          if k == @session_id
            marshalled_bytes = java_session.getAttribute(@session_id)
            if marshalled_bytes
              data = Marshal.load(String.from_java_bytes(marshalled_bytes))
              self.update data if Hash === data
            end
          else
            self[k] = java_session.getAttribute(k)
          end
        end
      end
    end

    def clear
      @_destroy = true
      finalize
    end

    def finalize(request=nil)
      @_destroy ? invalidate_java_session : save_to_java_session
    end
    
    def invalidate_java_session
      java_session = @java_request.getSession(false)
      java_session.invalidate if java_session
    end

    def save_to_java_session
      java_session = @java_request.getSession(true)
      data = self.to_hash
      data.delete_if do |k, v|
        if String === k
          case v
          when String, Numeric, true, false, nil
            java_session.setAttribute k, v
            true
          else
            if v.respond_to?(:java_object)
              java_session.setAttribute k, v
              true
            else
              false
            end
          end
        end
      end
      unless data.empty?
        marshalled_string = Marshal.dump(data)
        marshalled_bytes = marshalled_string.to_java_bytes
        java_session.setAttribute(@session_id, marshalled_bytes)
      end
    end

  end
end
