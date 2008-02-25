#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'rack/adapter/rails'

module Rack
  module Adapter
    class RailsFactory
      def self.new
        Rack::Builder.new {
          servlet_helper = RailsServletHelper.instance
          use StaticFiles, servlet_helper.public_root
          use RailsSetup, servlet_helper
          run Rails.new
        }.to_app
      end
    end
  end
end