#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/session_store'

module ActionDispatch
  module Session
    class JavaServletStore < JRuby::Rack::Session::SessionStore
      Store = AbstractStore
    end
  end
end
