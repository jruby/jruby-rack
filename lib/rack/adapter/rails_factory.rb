#--
# **** BEGIN LICENSE BLOCK *****
# Version: CPL 1.0/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Common Public
# License Version 1.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.eclipse.org/legal/cpl-v10.html
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# Copyright (C) 2007 Sun Microsystems, Inc.
#
# Alternatively, the contents of this file may be used under the terms of
# either of the GNU General Public License Version 2 or later (the "GPL"),
# or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
# in which case the provisions of the GPL or the LGPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of either the GPL or the LGPL, and not to allow others to
# use your version of this file under the terms of the CPL, indicate your
# decision by deleting the provisions above and replace them with the notice
# and other provisions required by the GPL or the LGPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the CPL, the GPL or the LGPL.
# **** END LICENSE BLOCK ****
#++

require 'rack/adapter/rails'

module Rack
  module Adapter
    class IndexHtmlFile < Rack::File
      def initialize(app, root)
        @app = app
	@file_server = Rack::File.new(root)
      end
      def call(env)
        result = if env["PATH_INFO"] =~ %r{/$}
          env = env.dup
          env["PATH_INFO"] = env["PATH_INFO"] + 'index.html'
          @file_server.call(env)
        end

        if result.nil? || result[0] == 404
          @app.call(env) 
        else
          result
        end
      end
    end

    class RailsFactory
      def self.new
        Rack::Builder.new {
          servlet_helper = RailsServletHelper.instance
          use Rack::Static, :urls => servlet_helper.static_uris, 
            :root => servlet_helper.public_root
          use Rack::Adapter::IndexHtmlFile, servlet_helper.public_root
          run Rack::Adapter::Rails.new
        }.to_app
      end
    end
  end
end