#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    # An application layout is defined as responding to three methods:
    # #app_path, #public_path and #gem_path.
    # Each method returns a (virtual) FS path where that portion of the app can
    # be loaded.
    # If you override the app layout by setting the **jruby.rack.layout_class**
    # option then you need to provide the three *_uri* suffixed methods.
    # @see JRuby::Rack::Booter#layout
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

      # Expands the given (URI) path into a real (FS) path.
      # @return [String]
      def real_path(path)
        real_path = @rack_context.getRealPath(path)
        real_path.chomp!('/') if real_path
        # just use the given path if there is no real path
        real_path
      end

    end

    # This is the default layout for a {JRuby::Rack::Booter} and assumes the
    # application is packaged using Java Servlet ("WEB-INF") conventions.
    # @note this layout is to be used when your app is packaged up with Warbler
    class WebInfLayout < AppLayout

      def initialize(context)
        super
        $0 = File.join(app_path, 'web.xml')
      end

      # Checks the **app.root** (and **rails.root**) init parameter.
      # Defaults to the '/WEB-INF' path.
      # @return [String]
      def app_uri
        @app_uri ||=
          @rack_context.getInitParameter('app.root') ||
          @rack_context.getInitParameter('rails.root') ||
          '/WEB-INF'
      end

      # Checks the **gem.path** and **gem.home** init parameters.
      # Defaults to the '/WEB-INF/gems' path.
      # @return [String]
      def gem_uri
        @gem_uri ||=
          @rack_context.getInitParameter('gem.path') ||
          @rack_context.getInitParameter('gem.home') ||
          '/WEB-INF/gems'
      end

      # Checks the **public.root** parameter (assumed to be a relative path).
      # Defaults to the (root) '/' path.
      # @return [String]
      def public_uri
        @public_uri ||= begin
          path = @rack_context.getInitParameter('public.root') || '/'
          path = "/#{path}" if path[0, 1] != '/'
          path.chomp!('/') unless path == '/'
          path
        end
      end

      # @return [String]
      # @see AppLayout#real_path
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

    # File system layout, simply assumes application is not packaged
    # (or expanded in a way as if it where not packaged previously).
    class FileSystemLayout < AppLayout

      # Checked from **app.root** (and **rails.root**) init parameter.
      # Defaults to '.' (current directory).
      # @return [String]
      def app_uri
        @app_uri ||=
          @rack_context.getInitParameter('app.root') ||
          @rack_context.getInitParameter('rails.root') ||
          '.'
      end

      # Checks the **gem.path** and **gem.home** init parameters.
      # @return [String]
      def gem_uri
        @gem_uri ||=
          @rack_context.getInitParameter('gem.path') ||
          @rack_context.getInitParameter('gem.home')
      end

      # Checks the **public.root** parameter (assumed to be a relative path).
      # Defaults to the (working-directory relative) './public' path.
      # @return [String]
      def public_uri
        @public_uri ||=
          @rack_context.getInitParameter('public.root') || 'public'
      end

      # @override
      # @note we avoid `context.getRealPath` completely and use (JRuby's) File API
      # @return [String]
      # @see AppLayout#real_path
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
    # @private backwards compatibility
    RailsFilesystemLayout = FileSystemLayout

  end
end
