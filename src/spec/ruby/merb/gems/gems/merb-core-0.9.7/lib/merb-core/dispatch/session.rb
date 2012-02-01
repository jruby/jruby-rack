#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Merb
  module SessionMixin
    class << self
      def rand_uuid; end
    end
  end

  class SessionContainer
    class << self
      attr_accessor :session_store_type
    end
  end
end
