module Merb
  module SessionMixin

    def self.included(base)
      base.add_hook :before_dispatch do
        Merb.logger.info("Setting Up Java servlet session")
        request.session = Merb::ServletSession.new(request)
      end
      
      base.add_hook :after_dispatch do
        Merb.logger.info("Finalizing Java servlet session")
        request.session.persist
      end
    end
    
    def session_store_type
      "servlet"
    end
  end
  
  class ServletSession
    MERB_SESSION_KEY = '__current_merb_session'
    
    attr_accessor :servlet_request
    attr_accessor :data
    
    def initialize(request)
      @servlet_request = request.env['java.servlet_request']
      @data = restore
    end
    
    def restore
      restored_data = {}
      java_session = servlet_request.getSession(false)
      if java_session
        marshalled_bytes = java_session.getAttribute(MERB_SESSION_KEY)
        if marshalled_bytes
          marshalled_string = String.from_java_bytes(marshalled_bytes)
          restored_data = Marshal.load(marshalled_string)
        end
      end
      @data = restored_data
    end
    
    def persist
      java_session = servlet_request.getSession(true) 
      marshalled_string = Marshal.dump(@data)
      marshalled_bytes = marshalled_string.to_java_bytes
      java_session.setAttribute(MERB_SESSION_KEY, marshalled_bytes)
    end
    
    def []=(k, v)
      @data[k] = v
    end
    
    def [](k)
      @data[k]
    end
    
    def each(&b)
      @data.each(&b)
    end
    
    def delete
      @data = {}
    end
    
    private

      # Attempts to redirect any messages to the data object.
      def method_missing(name, *args, &block)
        @data.send(name, *args, &block)
      end                              

  end
end
