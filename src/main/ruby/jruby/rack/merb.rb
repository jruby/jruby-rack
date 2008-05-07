require 'jruby/rack'
require 'cgi/session/java_servlet_store'

module JRuby
  module Rack
    class MerbServletHelper < ::JRuby::Rack::ServletHelper
      attr_reader :merb_environment, :merb_root

      def initialize(servlet_context = nil)
        super
        @merb_root = @servlet_context.getInitParameter('merb.root')
        @merb_root ||= '/WEB-INF'
        @merb_root = @servlet_context.getRealPath(@merb_root)

        @merb_environment = @servlet_context.getInitParameter('merb.environment')
        @merb_environment ||= 'production'
      end

      def load_environment
        load_merb
        setup_adapter
        setup_sessions
        start_merb
      end

      def load_merb
        framework = File.expand_path(File.join(@merb_root, 'framework'))
        if File.directory?(framework)
          logger.debug("Trying to load Merb from #{framework}")
          core = File.join(framework, 'merb-core')
          if File.directory?(core)
            $LOAD_PATH.push File.join(core, 'lib')
          end

          more = File.join(framework, 'merb-more')
          if File.directory?(more)
            Dir.new(more).select {|d| d =~ /merb-/}.each do |d|
              $LOAD_PATH.push File.join(more, d, 'lib')
            end
          end

          plugins = File.join(framework, 'merb-plugins')
          if File.directory?(plugins)
            Dir.new(plugins).select {|d| d =~ /merb_/}.each do |d|
              $LOAD_PATH.push File.join(plugins, d, 'lib')
            end
          end
        else
          logger.debug("Didn't find a framework/ directory, falling back to Rubygems")
          require 'rubygems'
        end

        require 'merb-core'
        require 'merb-core/rack'
        Merb.frozen!
      end

      def setup_adapter
        logger.debug('Registering Merb servlet adapter')
        Merb::Rack::Adapter.register %w{servlet}, :Servlet
      end

      def setup_sessions
        logger.debug('Registering Merb servlet sessions')
        Merb.register_session_type 'servlet',
          'jruby/rack/merb',
          'Using Java servlet sessions'
      end

      def start_merb
        logger.debug('Starting Merb')
        Merb.start :merb_root => merb_root,
                   :environment => merb_environment,
                   :adapter => 'servlet'
      end
    end

    class MerbFactory
      def self.new
        MerbServletHelper.new.load_environment
        ::Rack::Builder.new { run ::Merb::Config[:app] }.to_app
      end
    end
  end
end

# Merb likes to hardcode things into the Merb:: namespace.
module Merb
  module Rack
    class Servlet
      def self.start(opts={})
        Merb.logger.info("Using Java servlet adapter") if self == Merb::Rack::Servlet
        Merb.logger.flush
      end
    end
  end

  module SessionMixin
    def setup_session
      Merb.logger.info("Setting Up Java servlet session")
      opts = {'java_servlet_request' => request.env['java.servlet_request']}
      request.session = CGI::Session::JavaServletStore.new(nil, opts)
      request.session.restore
    end

    def finalize_session
      Merb.logger.info("Finalizing Java servlet session")
      request.session.update
    end

    def session_store_type
      "servlet"
    end
  end
end
