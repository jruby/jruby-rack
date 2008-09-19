# This is a stub Merb framework for testing
module Merb
  def self.start(*x); end

  module Rack
    module Adapter
      def self.register(*x); end
    end
  end
  
  Config = {}
end
