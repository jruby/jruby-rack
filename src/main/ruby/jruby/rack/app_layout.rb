#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    # An AppLayout is defined as responding to three methods:
    # {app,public,gem}_path. Each method returns a filesystem path
    # where that portion of the application can be loaded. The class
    # hierarchy here is just for implementation sharing; if you
    # override the app layout by [insert mechanism here], then you
    # only need to accept a rack context in your initializer and
    # provide the three *_uri methods.
    class AppLayout
      
      attr_reader :app_uri, :public_uri, :gem_uri

      def initialize(rack_context)
        @rack_context = rack_context
      end

      %w( app_path gem_path public_path ).each do |path|
        # def app_path; @app_path ||= real_path(app_uri); end
        # def app_path=(v); @app_path = v; end
        class_eval "def #{path}; @#{path} ||= real_path(#{path.sub('path', 'uri')}); end"
        class_eval "def #{path}=(path); @#{path} = path; end"
      end

      def real_path(path)
        if rpath = @rack_context.getRealPath(path)
          # protect windows paths from backrefs
          rpath.sub!(/\\([0-9])/, '\\\\\\\\\1')
          rpath.chomp!('/')
        end
        rpath
      end
      
    end

    class WebInfLayout < AppLayout
      
      def initialize(context)
        super
        $0 = File.join(app_path, 'web.xml')
      end

      def app_uri
        @app_uri ||= 
          @rack_context.getInitParameter('app.root') ||
          @rack_context.getInitParameter('rails.root') ||
          '/WEB-INF'
      end
      
      def gem_uri
        @gem_uri ||=
          @rack_context.getInitParameter('gem.path') ||
          @rack_context.getInitParameter('gem.home') ||
          '/WEB-INF/gems'
      end
      
      def public_uri
        @public_uri ||= begin
          path = @rack_context.getInitParameter('public.root') || '/'
          path = "/#{path}" if path[0, 1] != '/'
          path.chomp!('/') unless path == '/'
          path
        end
      end

      def real_path(path)
        app_regex = Regexp.quote(app_uri) # app_uri = '/WEB-INF'
        if path =~ /^#{app_regex}\// # gem_path = '/WEB-INF/gems'
          path.sub(/^#{app_regex}/, app_path) # '[app_path]/gems'
        else
          super
        end
      end
      
    end

    RailsWebInfLayout = WebInfLayout

    # #deprecated will be removed (with Merb support)
    class MerbWebInfLayout < WebInfLayout
      
      def app_uri
        @app_uri ||= @rack_context.getInitParameter('merb.root') || '/WEB-INF'
      end
      
    end

    class FileSystemLayout < AppLayout

      def app_uri
        @app_uri ||=
          @rack_context.getInitParameter('app.root') ||
          @rack_context.getInitParameter('rails.root') ||
          '.'
      end

      def gem_uri
        @gem_uri ||=
          @rack_context.getInitParameter('gem.path') ||
          @rack_context.getInitParameter('gem.home')
      end
      
      def public_uri
        @public_uri ||=
          @rack_context.getInitParameter('public.root') || './public'
      end

      def real_path(path)
        path.nil? ? nil : File.expand_path(path)
      end
      
    end
    
    RailsFileSystemLayout = FileSystemLayout
    RailsFilesystemLayout = FileSystemLayout # backwards compatibility
    
  end
end
