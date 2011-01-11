#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Myapp
  class Application
    def call(env)
      env['myapp.application'] = 'called'
      [200, {}, [""]]
    end
  end
end

Rails.application = Myapp::Application.new
