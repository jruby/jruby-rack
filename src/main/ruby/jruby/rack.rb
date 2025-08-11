#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'

module JRuby
  module Rack
    class << self
      # @private the (last) `JRuby::Rack::Booter` that performed `boot!` (used with tests)
      attr_reader :booter

      # @return [String] the application (root) path.
      # @see JRuby::Rack::Booter#export_global_settings
      def app_path
        @app_path ||= begin
          path = context.getRealPath('/') if context
          path || Dir.pwd
        end
      end
      # Set the application (root) path.
      # @see JRuby::Rack::Booter
      attr_writer :app_path

      # The public path is the directory to be mapped as the "document" root.
      # @return [String] the public directory path (defaults to {#app_path}).
      # @see JRuby::Rack::Booter#export_global_settings
      def public_path
        return @public_path if defined? @public_path
        @public_path = app_path
      end
      # Set the public directory path (where static assets are located).
      # @see JRuby::Rack::Booter
      attr_writer :public_path

      # Returns the "global" `JRuby::Rack` context.
      # @return [Java::OrgJRubyRack::RackContext]
      # most likely a [Java::OrgJRubyRackServlet::ServletRackContext]
      def context; @context ||= $servlet_context end

      # Sets the ("global") context for `JRuby::Rack`.
      def context=(context)
        @context = context
        @@logger = nil # reset the logger
      end

      @@logger = nil
      # Returns a {Logger} instance that uses the {#context} as a logger.
      def logger; @@logger ||= Logger.new(context) end
      # @private only used with tests
      def logger=(logger); @@logger = logger end

      private

      # @deprecated Mostly for compatibility - not used anymore.
      def logdev; ServletLog.new(context) end
      alias servlet_log logdev

    end
  end
end

# TODO remove require 'jruby/rack/version' from jruby-rack in 1.2
require 'jruby/rack/version' unless defined? JRuby::Rack::VERSION
require 'jruby/rack/helpers'
require 'jruby/rack/booter'
require 'jruby/rack/response'
require 'jruby/rack/servlet_ext'
require 'jruby/rack/core_ext'

# loading Rack is delayed to allow the application to boot it's desired Rack
# version (if it needs one) e.g. in a Rails application until Bundler setups
JRuby::Rack::Booter.on_boot { require 'jruby/rack/rack_ext' }
