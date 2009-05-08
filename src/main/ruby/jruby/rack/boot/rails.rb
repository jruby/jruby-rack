#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/adapter/rails'

module JRuby::Rack
  self.booter = RailsBooter.new
end
