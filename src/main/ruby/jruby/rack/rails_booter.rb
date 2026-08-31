#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/booter'

module JRuby::Rack
  # A booter for loading and booting `Rails` applications.
  class RailsBooter < Booter
    attr_reader :rails_env

    def initialize(rack_context = nil)
      super
      @rails_env = ENV['RAILS_ENV'] ||
        @rack_context.getInitParameter('rails.env') || rack_env || 'production'
    end

    # @see Booter#default_layout_class
    def self.default_layout_class; RailsWebInfLayout; end

    # @see Booter#boot!
    def boot!
      super
      ENV['RAILS_ROOT'] = app_path
      ENV['RAILS_ENV'] = rails_env
      self
    end

    # @return [Rails::Application] the (loaded) application instance
    def to_app
      # backward "compatibility" calling #to_app without a #load_environment
      load_environment
      ::Rails.application
    end

    # Loads the Rails environment (*config/environment.rb*).
    def load_environment
      require rails_boot_path
      require 'jruby/rack/rails/railtie'
      require expand_path('config/environment.rb')
      require 'jruby/rack/rails/extensions'
    end

    protected

    # For a Rails booter bundler setup is delayed to be run during the (Rails) environment load so we can
    # determine whether Rails requires opinionated bundler pre-boot.
    # @see JRuby::Rack::RailsBooter#load_environment
    # @see #rails_boot_path
    def prepare_bundler
      # no-op, deferred
    end

    def set_relative_url_root
      if rails_relative_url_root = relative_url_root('rails.relative_url_append')
        ENV['RAILS_RELATIVE_URL_ROOT'] = rails_relative_url_root
      end
    end

    def rails_boot_path
      user_boot = expand_path('config/boot.rb')
      # pre-boot bundler if the user boot.rb appears to be using CLI/default bundler setup
      boot_bundler! if default_rails_bundler_boot?(user_boot)
      user_boot
    end

    # For a Rails booter the boot hooks are delayed to be run after the (Rails) environment gets loaded, before
    # extensions.
    # @see JRuby::Rack::RailsBooter#load_environment / jruby/rack/rails/extensions
    # @see JRuby::Rack::Booter#run_boot_hooks
    # @see JRuby::Rack::Railtie#
    def run_boot_hooks
      # no-op, deferred
    end

    private

    def default_rails_bundler_boot?(boot_rb_path)
      return unless ENV['BUNDLE_GEMFILE'] # not a bundled application
      boot_rb_content = File.read(boot_rb_path) if File.readable?(boot_rb_path)

      # Assume default if there is a `require 'bundler/setup'` and no custom Bundler management e.g
      # explicit `Bundler.setup(...)` call or `BUNDLE_WITHOUT` hardcoded.
      boot_rb_content &&
        %r{^\s*require\s+["']bundler/setup["']} =~ boot_rb_content &&
        %r{Bundler\.setup} !~ boot_rb_content &&
        %r{BUNDLE_WITHOUT} !~ boot_rb_content
    end

    class << self

      # @see #RailsRackApplicationFactory
      # @private
      def load_environment; rails_booter.load_environment end

      # @see #RailsRackApplicationFactory
      # @private
      def to_app; rails_booter.to_app end

      private

      # @private
      def rails_booter
        raise "no booter set" unless (booter = JRuby::Rack.booter)
        raise "not a rails booter" unless booter.is_a?(JRuby::Rack::RailsBooter)
        booter
      end

    end
  end
end
