# This is a fake Merb config/boot file to be used during testing.

module Merb
  class Config
    def self.defaults; {}; end
  end
  
  class Server
    def self.initialize_merb; end
    def self.config; {} end
    def self.register_session_type(*args); end
  end
end
