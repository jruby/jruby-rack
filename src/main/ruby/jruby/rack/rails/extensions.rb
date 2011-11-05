#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'action_controller'

module ActionController
  class Base
    def servlet_request
      request.env['java.servlet_request']
    end
    
    def forward_to(url)
      request.forward_to(url)
    end
  end
end
