#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'java'

module JRuby
  module Rack
    
    # @deprecated use {JRuby::Rack::Helpers#silence_warnings} instead
    def self.silence_warnings(&block)
      Helpers.silence_warnings(&block)
    end
    
    def self.booter; @booter; end # :nodoc TODO do we need to keep after boot! ?!
    
    # @return [String] the application (root) path.
    # @see JRuby::Rack::Booter#export_global_settings
    def self.app_path
      @app_path ||= begin 
        app_path = context.getRealPath('/') if context
        app_path || Dir.pwd
      end
    end

    # Set the application (root) path.
    # @see JRuby::Rack::Booter
    def self.app_path=(app_path)
      @app_path = app_path
    end
    
    # The public path is the directory to be mapped as your "document" root.
    # @return [String] the public directory path (defaults to {#app_path}).
    # @see JRuby::Rack::Booter#export_global_settings
    def self.public_path
      return @public_path if defined? @public_path
      @public_path = app_path
    end
    
    # Set the public directory path (where static assets are located).
    # @see JRuby::Rack::Booter
    def self.public_path=(public_path)
      @public_path = public_path
    end
    
    # Returns the "global" `JRuby::Rack` context.
    # @return [Java::OrgJRubyRack::RackContext] 
    # most likely a [Java::OrgJRubyRackServlet::ServletRackContext]
    def self.context
      @context ||= $servlet_context
    end
    
    # Sets the ("global") context for `JRuby::Rack`.
    def self.context=(context)
      @logger = nil # reset the logger
      @context = context
    end
    
    # Returns a {Logger} instance that uses the {#context} as a log device.
    def self.logger
      @logger ||= begin; require 'logger'; Logger.new(logdev); end
    end
    
    private
    
    def self.logdev
      ServletLog.new context
    end
  
  end
end

require 'jruby/rack/helpers'
require 'jruby/rack/servlet_log'
require 'jruby/rack/booter'
require 'jruby/rack/response'
require 'jruby/rack/servlet_ext'
require 'jruby/rack/core_ext'
require 'jruby/rack/bundler_ext'

# loading Rack is delayed to allow the application to boot it's desired Rack
# version (if it needs one) e.g. in a Rails application until Bundler setups
JRuby::Rack::Booter.on_boot { require 'jruby/rack/rack_ext' }