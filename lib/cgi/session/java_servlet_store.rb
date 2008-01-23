class CGI #:nodoc:all
  class Session
    class JavaServletStore
      RAILS_SESSION_KEY = "__current_rails_session"

      def initialize(session, option=nil)
        @java_request = option["java_servlet_request"] if option
        unless @java_request
          raise 'JavaServletStore requires that HttpServletRequest is made available to the session'
        end
        @session_data = {}
      end

      # Restore session state from the Java session
      def restore
        @session_data = {}
        java_session = @java_request.getSession(false)
        if java_session
          marshalled_bytes = java_session.getAttribute(RAILS_SESSION_KEY)
          if marshalled_bytes
            marshalled_string = String.from_java_bytes(marshalled_bytes)
            @session_data = Marshal.load(marshalled_string)
          end
        end
        @session_data
      end

      # Save session state to the Java session
      def update
        java_session = @java_request.getSession(true)
        hash = @session_data.dup
        hash.delete_if do |k,v|
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
        unless hash.empty?
          marshalled_string = Marshal.dump(hash)
          marshalled_bytes = marshalled_string.to_java_bytes
          java_session.setAttribute(RAILS_SESSION_KEY, marshalled_bytes)
        end
      end

      # Update and close the Java session entry
      def close
        update
      end

      # Delete the Java session entry
      def delete
        java_session = @java_request.getSession(false)
        java_session.invalidate if java_session
      end

      # The session state
      def data
        @session_data
      end
    end
  end
end
