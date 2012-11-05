#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    def self.silence_warnings
      oldv, $VERBOSE = $VERBOSE, nil
      begin
        yield
      ensure
        $VERBOSE = oldv
      end
    end
    
    def self.booter; @booter; end # TODO do we need to keep after boot! ?!
    
    def self.app_path
      @app_path ||= begin 
        app_path = context.getRealPath('/') if context
        app_path || Dir.pwd
      end
    end

    def self.app_path=(app_path)
      @app_path = app_path
    end
    
    def self.public_path
      return @public_path if defined? @public_path
      @public_path = app_path
    end
    
    def self.public_path=(public_path)
      @public_path = public_path
    end
    
    def self.context
      @context ||= $servlet_context
    end
    
    def self.context=(context)
      @logger = nil # reset the logger
      @context = context
    end
    
    def self.logger
      @logger ||= begin; require 'logger'; Logger.new(logdev); end
    end
    
    private
    
    def self.logdev
      ServletLog.new context
    end
  
  end
end

require 'jruby/rack/environment'
require 'jruby/rack/app_layout'
require 'jruby/rack/errors'
require 'jruby/rack/response'
require 'jruby/rack/servlet_log'
require 'jruby/rack/booter'
require 'jruby/rack/servlet_ext'
require 'jruby/rack/core_ext'
require 'jruby/rack/bundler_ext'

# require 'rack' should be delayed to allow the app to boot it's own Rack
# version if it needs one e.g. in a Rails application util Bundler starts
