#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/session_store'

module ActionController
  module Session
    class JavaServletStore
      Store = AbstractStore
      include JRuby::Rack::SessionStore
    end
  end
end
