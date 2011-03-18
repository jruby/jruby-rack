#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/capture'

def debug?
  $DEBUG || !ENV['DEBUG'].nil?
end

class Exception
  include JRuby::Rack::Capture::Base
  include JRuby::Rack::Capture::Exception
  include JRuby::Rack::Capture::Environment if debug?
  include JRuby::Rack::Capture::RubyGems
  include JRuby::Rack::Capture::Bundler
  include JRuby::Rack::Capture::JRubyRackConfig
  include JRuby::Rack::Capture::JavaEnvironment if debug?
end

class LoadError
  include JRuby::Rack::Capture::LoadPath
end

class NativeException
  include JRuby::Rack::Capture::Native
end
