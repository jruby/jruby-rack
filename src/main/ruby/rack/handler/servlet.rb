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

      # @deprecated please use #create_env instead
      def create_lazy_env(servlet_env)
        DefaultEnv.new(servlet_env).to_hash
      end

      @@env = nil
      def self.env; @@env ||= DefaultEnv; end

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

      @@response = nil
      def self.response; @@response ||= JRuby::Rack::Response; end

      def self.response=(klass)
        if klass && ! klass.is_a?(Module)
          klass = JRuby::Rack::Helpers.resolve_constant(klass, JRuby::Rack)
        end
        @@response = klass
      end

    end
    # @deprecated backwards compatibility
    LazyEnv = Env = Servlet::DefaultEnv
  end
end
