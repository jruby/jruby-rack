#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Java::OrgJrubyRack::RackEnvironment
  # @_io instance variable should be set during incoming request; 
  # @deprecated replaced with org.jruby.rack.RackEnvironment#setIO
  # @see org.jruby.rack.DefaultRackApplication
  def to_io
    @_io
  end
end