#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/session_store'

module ActionDispatch
  module Session
    class JavaServletStore
      Store = AbstractStore
      include JRuby::Rack::SessionStore
    end
  end
end
