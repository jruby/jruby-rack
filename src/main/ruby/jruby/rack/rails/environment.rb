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
    require expand_path('config/boot.rb')
    require 'jruby/rack/rails/railtie'
    require expand_path('config/environment.rb')
    require 'jruby/rack/rails/extensions'
  end

  protected

  # The public root is set in {JRuby::Rack::Railtie}.
  def set_public_root
    # no-op here
  end

end