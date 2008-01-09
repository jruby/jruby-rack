require 'rack/adapter/merb'

module Rack
  module Adapter
    class MerbFactory
      def self.new
        Rack::Builder.new {
          servlet_helper = MerbServletHelper.instance
          use StaticFiles, servlet_helper.public_root
          run Merb.new
        }.to_app
      end
    end
  end
end