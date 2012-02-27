#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rack
  module Adapter
    class Rails
      def initialize(options={})
        @root   = options[:root]   || Dir.pwd
        @public = options[:public] || ::File.join(@root, "public")
        @file_server = Rack::File.new(@public)
        if defined?(ActionController::Dispatcher.middleware)
          @dispatcher = ActionController::Dispatcher.new
        else
          require 'rack/adapter/rails_cgi'
          @dispatcher = Rack::Adapter::RailsCgi.new
        end
      end

      # TODO refactor this in File#can_serve?(path) ??
      def file_exist?(path)
        full_path = ::File.join(@file_server.root, Utils.unescape(path))
        ::File.file?(full_path) && ::File.readable?(full_path)
      end

      def serve_file(env)
        @file_server.call(env)
      end

      def serve_rails(env)
        @dispatcher.call(env)
      end

      def call(env)
        if env['jruby.rack.dynamic.requests.only']
          serve_rails(env)
        else
          path        = env['PATH_INFO'].chomp('/')
          cached_path = (path.empty? ? 'index' : path) + ActionController::Base.page_cache_extension

          if file_exist?(path)              # Serve the file if it's there
            serve_file(env)
          elsif file_exist?(cached_path)    # Serve the page cache if it's there
            env['PATH_INFO'] = cached_path
            serve_file(env)
          else                              # No static file, let Rails handle it
            serve_rails(env)
          end
        end
      end
    end
  end
end
