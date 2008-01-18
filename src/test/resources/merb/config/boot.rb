# This is a fake Merb config/boot file to be used during testing.

module Merb
  class << self
    def logger=(*args); end
  end
  
  class Config
    class << self
      def setup(*args); end
      def []=(*args); end
      def [](*args); end
    end
  end
  
  class BootLoader
    class << self
      def initialize_merb; end
      def register_session_type(*args); end
    end
  end
end