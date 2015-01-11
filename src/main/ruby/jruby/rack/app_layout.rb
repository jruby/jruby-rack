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

      def initialize(rack_context)
        @rack_context = rack_context
      end

      attr_reader :app_uri, :gem_uri, :public_uri

      def app_path; @app_path ||= real_path(app_uri) end
      def gem_path; @gem_path ||= real_path(gem_uri) end
      def public_path; @public_path ||= real_path(public_uri) end

      attr_writer :app_path, :gem_path, :public_path

      def expand_path(path)
        if real_path = self.real_path(path)
          # protect windows paths from backrefs
          real_path.sub!(/\\([0-9])/, '\\\\\\\\\1')
          real_path.chomp!('/')
        end
        real_path
      end

      def real_path(path)
        real_path = @rack_context.getRealPath(path)
        real_path.chomp!('/') if real_path
        # just use the given path if there is no real path
        real_path
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

      def expand_path(path)
        return nil if path.nil?
        if path.start_with?(app_uri) # gem_path = '/WEB-INF/gems'
          path = path.dup; path[0, app_uri.size] = app_path; path # '[app_path]/gems'
          path
        elsif path[0, 1] != '/' # expand relative paths
          File.join(app_path, path)
        else
          super
        end
      end

    end

    RailsWebInfLayout = WebInfLayout

    class ClassPathLayout < WebInfLayout

      URI_CLASSLOADER = 'uri:classloader://'

      def real_path(path)
        if path.start_with? URI_CLASSLOADER
          path
        else
          super
        end
      end

      def app_uri
        @app_uri ||=
          @rack_context.getInitParameter('app.root') ||
          URI_CLASSLOADER
      end

      def gem_uri
        @gem_uri ||=
          @rack_context.getInitParameter('gem.path') ||
          URI_CLASSLOADER
      end
    end

    # @deprecated will be removed (with Merb support)
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
          @rack_context.getInitParameter('public.root') || 'public'
      end

      # @override
      # @note we avoid `context.getRealPath` completely and use (JRuby's) File API
      def real_path(path)
        return nil if path.nil?
        path = File.expand_path(path, app_uri)
        File.exist?(path) ? path : nil
      end

      # @override
      def expand_path(path)
        path.nil? ? nil : File.expand_path(path, app_uri)
      end

    end

    RailsFileSystemLayout = FileSystemLayout
    RailsFilesystemLayout = FileSystemLayout # backwards compatibility

  end
end
