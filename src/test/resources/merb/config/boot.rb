# This is a fake Merb config/boot file to be used during testing.

module Merb
  class Config
    def self.defaults; {}; end
  end
  
  class Server
    def self.initialize_merb; end
    def self.config; {} end
  end
end
