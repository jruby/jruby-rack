#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    def self.silence_warnings
      oldv, $VERBOSE = $VERBOSE, nil
      begin
        yield
      ensure
        $VERBOSE = oldv
      end
    end

    def self.booter=(booter)
      @booter = booter
    end

    def self.booter
      @booter
    end
  end
end

require 'jruby/rack/environment'
require 'jruby/rack/app_layout'
require 'jruby/rack/errors'
require 'jruby/rack/response'
require 'jruby/rack/servlet_log'
require 'jruby/rack/booter'
require 'jruby/rack/servlet_ext'
require 'jruby/rack/core_ext'
require 'jruby/rack/bundler_ext'
require 'jruby/rack/rack_ext'
