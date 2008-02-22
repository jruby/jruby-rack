require 'rack/adapter/servlet_helper'

module Merb
  module Rack
    class ServletHelper < ::Rack::Adapter::ServletHelper
      attr_reader :merb_environment, :merb_root

      def initialize(servlet_context = nil)
        super
        @merb_root = @servlet_context.getInitParameter('merb.root')
        @merb_root ||= '/WEB-INF'
        @merb_root = @servlet_context.getRealPath(@merb_root)

        @merb_environment = @servlet_context.getInitParameter('merb.environment')
        @merb_environment ||= 'production'
      end

      def load_merb
        logger.info("Loading Merb framework")

        framework = File.join(@merb_root, 'framework')
        if File.directory?(framework)
          load_frozen_merb(framework)
        else
          raise "Couldn't find a Merb framework to load"
        end
      end

      def load_frozen_merb(dir)
        logger.debug "Trying to load a frozen Merb from #{dir}"

        core = File.join(dir, 'merb-core')
        if File.directory?(core)
          $LOAD_PATH.push File.join(core, 'lib')
        end

        more = File.join(dir, 'merb-more')
        if File.directory?(more)
          Dir.new(more).select {|d| d =~ /merb-/}.each do |d|
            $LOAD_PATH.push File.join(more, d, 'lib')
          end
        end

        plugins = File.join(dir, 'merb-plugins')
        if File.directory?(plugins)
          Dir.new(plugins).select {|d| d =~ /merb_/}.each do |d|
            $LOAD_PATH.push File.join(plugins, d, 'lib')
          end
        end

        require 'merb-core'
        require 'merb-core/rack'
        Merb.frozen!
      end

    end

  end
end