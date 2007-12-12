module Rack
  module Adapter
    ServletContext = $servlet_context
    class ServletHelper
      attr_reader :public_root, :gem_path

      def initialize(servlet_context = nil)
        @servlet_context = servlet_context || ServletContext
        @public_root = @servlet_context.getInitParameter 'public.root'
        @public_root ||= '/WEB-INF/public'
        @public_root = @servlet_context.getRealPath @public_root
        @gem_path = @servlet_context.getInitParameter 'gem.path'
        @gem_path ||= '/WEB-INF/gems'
        @gem_path = @servlet_context.getRealPath @gem_path
        setup_gems
      end
      
      def logdev
        unless @logdev
          @logdev = Proc.new {|msg| @servlet_context.log msg }
          def @logdev.write(msg); call(msg); end
          def @logdev.close; end
        end
        @logdev
      end

      def logger
        require 'logger'
        Logger.new(logdev)
      end

      def setup_gems
        begin
          require 'rubygems'
        rescue LoadError
          $LOAD_PATH << 'META-INF/jruby.home/lib/ruby/site_ruby/1.8'
          require 'rubygems'
        end
        Gem.clear_paths
        Gem.path << @gem_path
      end

      def self.instance
        @instance ||= self.new
      end      
    end

    class StaticFiles
      def initialize(app, root)
        @app = app
        @file_server = Rack::File.new(root)
      end

      def call(env)
        if env["PATH_INFO"] =~ %r{/$}
          file_env = env.dup
          file_env["PATH_INFO"] = env["PATH_INFO"] + 'index.html'
        else
          file_env = env
        end

        result = @file_server.call(file_env)
        if result[0] == 404
          @app.call(env) 
        else
          result
        end
      end
    end

  end
end