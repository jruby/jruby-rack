module Merb
  module SessionMixin
    class << self
      def rand_uuid; end
    end
  end

  class SessionContainer
    class << self
      attr_accessor :session_store_type
    end
  end
end
