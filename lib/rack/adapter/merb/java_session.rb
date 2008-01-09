module Merb
  module SessionMixin
    def setup_session
      MERB_LOGGER.info("Setting Up Java Session")
      request.session = {}
      java_session = request.env['java.servlet_request'].getSession(false)
      if java_session
        marshalled_bytes = java_session.getAttribute('__current_merb_session')
        if marshalled_bytes
          marshalled_string = String.from_java_bytes(marshalled_bytes)
          request.session = Marshal.load(marshalled_string)
        end
      end
    end

    def finalize_session
      MERB_LOGGER.info("Finalizing Java Session")
      java_session = request.env['java.servlet_request'].getSession(true)
      marshalled_string = Marshal.dump(request.session)
      marshalled_bytes = marshalled_string.to_java_bytes
      java_session.setAttribute('__current_merb_session', marshalled_bytes)
    end

    def session_store_type
      "java"
    end
  end
end
