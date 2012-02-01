#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rails
  class << self
    attr_accessor :application
  end
end

require File.expand_path('../application', __FILE__)
