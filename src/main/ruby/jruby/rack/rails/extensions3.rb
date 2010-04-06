#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'action_dispatch'
module ActionDispatch
  module Session
    autoload :JavaServletStore, "action_dispatch/session/java_servlet_store"
  end
end
