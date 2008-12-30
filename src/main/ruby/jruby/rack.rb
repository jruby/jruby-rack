#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack'
require 'time' # some of rack uses Time#rfc822 but doesn't pull this in

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
  end
end

require 'jruby/rack/app_layout'
require 'jruby/rack/errors'
require 'jruby/rack/response'
require 'jruby/rack/servlet_log'
require 'jruby/rack/servlet_helper'
require 'jruby/rack/servlet_ext'
