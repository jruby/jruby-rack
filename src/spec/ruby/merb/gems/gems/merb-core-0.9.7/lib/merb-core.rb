#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# This is a stub Merb framework for testing
module Merb
  def self.start(*x); end

  module Rack
    module Adapter
      def self.register(*x); end
    end
  end
  
  Config = {}
end
