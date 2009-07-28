#--
# Copyright 2007-2009 Sun Microsystems, Inc.
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
    # provide the three *_path methods.
    class AppLayout
      attr_reader :app_uri, :public_uri, :gem_uri

      def initialize(rack_context)
        @rack_context = rack_context
      end

      %w(app_path gem_path public_path).each do |m|
        # def app_path; @app_path ||= real_path(app_uri); end
        # def app_path=(v); @app_path = v; end
        class_eval "def #{m}; @#{m} ||= real_path(#{m.sub(/path$/,'uri')}); end"
        class_eval "def #{m}=(v); @#{m} = v; end"
      end

      def real_path(path)
        rpath = @rack_context.getRealPath(path)
        # protect windows paths from backrefs
        rpath.sub!(/\\([0-9])/, '\\\\\\\\\1') if rpath
        rpath
      end

    end

    class WebInfLayout < AppLayout
      def initialize(context)
        super
        $0 = File.join(app_path, "web.xml")
      end

      def public_uri
        @public_uri ||= begin
          path = @rack_context.getInitParameter('public.root') || '/'
          path = "/#{path}" unless path =~ %r{^/}
          path.chomp!("/") unless path == "/"
          path
        end
      end

      def app_uri
        @app_uri ||= '/WEB-INF'
      end

      def gem_uri
        @gem_uri ||= @rack_context.getInitParameter('gem.path') || '/WEB-INF/gems'
      end

      def real_path(path)
        rx = Regexp.quote(app_uri)
        if path =~ /^#{rx}\//
          path.sub(/^#{rx}/, app_path)
        else
          super
        end
      end

      def change_working_directory
        Dir.chdir(app_path) if File.directory?(app_path)
      end
    end

    class RailsWebInfLayout < WebInfLayout
      def app_uri
        @app_uri ||= @rack_context.getInitParameter('rails.root') || '/WEB-INF'
      end
    end

    class MerbWebInfLayout < WebInfLayout
      def app_uri
        @app_uri ||= @rack_context.getInitParameter('merb.root') || '/WEB-INF'
      end
    end
  end
end
