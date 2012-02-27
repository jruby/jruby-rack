#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/rails_booter'

# Rails 3.x specific booter extensions
# @see also #JRuby::Rack::Railtie
module JRuby::Rack::RailsBooter::Rails3Environment

  def to_app
    # backward "compatibility" calling #to_app without a #load_environment
    load_environment
    ::Rails.application
  end
  
  def load_environment
    require File.join(app_path, 'config', 'boot')
    require 'jruby/rack/rails/railtie'
    require File.join(app_path, 'config', 'environment')
    require 'jruby/rack/rails/extensions3'
  end

  protected
  
  def set_public_root
    # set in a railtie hook @see #JRuby::Rack::Railtie
  end
  
end