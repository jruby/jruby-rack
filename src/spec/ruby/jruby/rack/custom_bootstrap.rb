#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

class MyLayout < JRuby::Rack::AppLayout
  def initialize(context)
    super
    @app_path = "/app"
    @public_path = "/web"
  end
end

JRuby::Rack::ServletHelper.layout_class = MyLayout
