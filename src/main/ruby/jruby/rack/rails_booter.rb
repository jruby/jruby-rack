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
      user_boot = expand_path('config/boot.rb')
      prepare_bundler(user_boot)
      require user_boot
      require 'jruby/rack/rails/railtie'
      require expand_path('config/environment.rb')
      require 'jruby/rack/rails/extensions'
    end

    protected

    def set_relative_url_root
      if rails_relative_url_root = relative_url_root('rails.relative_url_append')
        ENV['RAILS_RELATIVE_URL_ROOT'] = rails_relative_url_root
      end
    end

    # no rack etc extensions required here (called during boot!)
    # require 'jruby/rack/rails/extensions' on #load_environment

    # For a Rails booter the boot hooks are delayed to be run after the
    # (Rails) environment gets loaded.
    # @see JRuby::Rack::Railtie
    # @see JRuby::Rack::Booter#run_boot_hooks
    def run_boot_hooks
      # no-op hooks run when 'jruby/rack/rails/extensions' gets loaded
    end

    private

    # For a default (unmodified) Rails *config/boot.rb*, runs `Bundler.setup` up-front. `bundler/setup` can swallow setup
    # errors and end up calling `exit` when it believes stdout is a tty (which is frequently mis-detected under a servlet
    # container); pre-booting makes failures raise instead, so the container logs the actual error.
    def prepare_bundler(boot_rb_path)
      return unless ENV['BUNDLE_GEMFILE'] # not a bundled application

      if rails_has_default_bundler_boot?(boot_rb_path)
        # pre-boot bundler with groups respecting BUNDLE_WITHOUT from the environment
        require 'bundler'
        Bundler.ui.silence { Bundler.setup }
      end
    end

    def rails_has_default_bundler_boot?(boot_rb_path)
      boot_rb_content = File.read(boot_rb_path) if File.readable?(boot_rb_path)
      return false unless boot_rb_content
      # Assume default if there is a `require 'bundler/setup'` and no `BUNDLE_WITHOUT` in the boot.rb file.
      %r{^\s*require\s+["']bundler/setup["']} =~ boot_rb_content && %r{BUNDLE_WITHOUT} !~ boot_rb_content
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
        raise "no booter set" unless booter = JRuby::Rack.booter
        raise "not a rails booter" unless booter.is_a?(JRuby::Rack::RailsBooter)
        booter
      end

    end
  end
end
