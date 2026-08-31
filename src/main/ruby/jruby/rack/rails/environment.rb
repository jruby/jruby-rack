#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/rails_booter'

# Rails 3.x specific booter behavior.
# @see JRuby::Rack::Railtie
module JRuby::Rack::RailsBooter::RailsEnvironment

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

  # The public root is set in {JRuby::Rack::Railtie}.
  def set_public_root
    # no-op here
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

    # Assume default if there is a `require 'bundler/setup'` and no custom Bundler management e.g
    # explicit `Bundler.setup(...)` call or `BUNDLE_WITHOUT` hardcoded.
    %r{^\s*require\s+["']bundler/setup["']} =~ boot_rb_content &&
      %r{Bundler\.setup} !~ boot_rb_content &&
      %r{BUNDLE_WITHOUT} !~ boot_rb_content
  end

end