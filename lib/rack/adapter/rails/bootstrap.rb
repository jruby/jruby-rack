#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'rack/adapter/rails/servlet_helper'
ENV['RAILS_ROOT'] = Rack::Adapter::RailsServletHelper.instance.rails_root
ENV['RAILS_ENV'] = Rack::Adapter::RailsServletHelper.instance.rails_env
RAILS_DEFAULT_LOGGER = Rack::Adapter::RailsServletHelper.instance.logger

load File.join(ENV['RAILS_ROOT'], 'config', 'environment.rb')

Rack::Adapter::RailsServletHelper.instance.setup_sessions

require 'rack/adapter/rails/factory'
