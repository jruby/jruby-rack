#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rails
  # A mock Railtie class for specs to use
  class Railtie
    def self.initializer(name, *options, &block)
      self.initializers << [name, options, block]
    end

    def self.initializers
      @@initializers ||= []
    end
  end
end
