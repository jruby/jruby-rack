#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/capture'

$DEBUG ||= ! ENV['DEBUG'].nil?

class Exception
  include JRuby::Rack::Capture::Base
  include JRuby::Rack::Capture::Exception
  include JRuby::Rack::Capture::Environment if $DEBUG
  include JRuby::Rack::Capture::RubyGems
  include JRuby::Rack::Capture::Bundler
  include JRuby::Rack::Capture::JRubyRackConfig
  include JRuby::Rack::Capture::JavaEnvironment if $DEBUG
end

class LoadError
  include JRuby::Rack::Capture::LoadPath
end
