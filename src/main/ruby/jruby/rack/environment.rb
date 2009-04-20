#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Java::OrgJrubyRack::RackEnvironment
  # @_io instance variable should be set during incoming request; see
  # DefaultRackApplication Java class
  def to_io
    @_io
  end
end