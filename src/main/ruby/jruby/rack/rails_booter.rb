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
      require expand_path('config/boot.rb')
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

    # @deprecated no longer used, replaced with {#run_boot_hooks}
    def load_extensions
      # no-op
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
