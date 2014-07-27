#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rails
  class Initializer
    def self.run(method = :process)
      initializer = new
      initializer.send(method)
      initializer
    end

    def set_load_path
    end

    def process
      require_frameworks
    end

    def require_frameworks
      require 'action_controller'
    end
  end
end
