#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rack/adapter/rails'

module JRuby::Rack
  silence_warnings do
    const_set('Bootstrap', RailsServletHelper)
  end
end
