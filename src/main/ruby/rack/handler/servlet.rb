#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'
require 'jruby/rack/version'

module Rack
  module Handler
    class Servlet
      
      def initialize(rack_app)
        unless @rack_app = rack_app
          raise "rack application not found. Make sure the rackup file path is correct."
        end
      end

      def call(servlet_env)
        JRuby::Rack::Response.new(@rack_app.call(create_env(servlet_env)))
      end

      def create_env(servlet_env)
        self.class.env.create(servlet_env).to_hash
      end
      
      # #deprecated please use #create_env instead
      def create_lazy_env(servlet_env)
        DefaultEnv.new(servlet_env).to_hash
      end
      
      @@env = nil
      
      def self.env
        @@env ||= DefaultEnv
      end
      
      def self.env=(klass)
        if klass && ! klass.is_a?(Module)
          # accepting a String or Symbol:
          unless (const_defined?(klass) rescue nil)
            klass = "#{klass.to_s.capitalize}Env" # :default => 'DefaultEnv'
          end
          klass = const_get(klass)
        end
        @@env = klass
      end
      
      autoload :DefaultEnv, "rack/handler/servlet/default_env"
      autoload :ServletEnv, "rack/handler/servlet/servlet_env"
      
    end
    # #deprecated backwards compatibility
    LazyEnv = Env = Servlet::DefaultEnv
  end
end
