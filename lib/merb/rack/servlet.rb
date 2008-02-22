require 'rack/handler/servlet'

module Merb
  module Rack
    class Servlet
      def self.start(opts={})
        Merb.logger.info("Using Java servlet adapter") if self == Merb::Rack::Servlet
        Merb.logger.flush
      end
    end
  end
end
