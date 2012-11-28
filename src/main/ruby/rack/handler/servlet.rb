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
        unless @app = rack_app
          raise "rack application not found. Make sure the rackup file path is correct."
        end
      end

      def call(servlet_env)
        JRuby::Rack::Response.new(@app.call(create_env(servlet_env)))
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
            klass_env = "#{klass.to_s.capitalize}Env" # :default => 'DefaultEnv'
            if (const_defined?(klass_env) rescue nil)
              klass = const_get(klass_env)
            end
          else
            klass = const_get(klass)
          end
          unless klass.is_a?(Module)
            klass = JRuby::Rack::Helpers.resolve_constant(klass)
          end
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
