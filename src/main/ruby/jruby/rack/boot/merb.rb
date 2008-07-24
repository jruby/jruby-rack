#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/merb'

module JRuby::Rack
  silence_warnings do
    const_set('Bootstrap', MerbServletHelper)
  end
end
