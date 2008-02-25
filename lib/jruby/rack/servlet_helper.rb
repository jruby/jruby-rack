#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    class Result
      include org.jruby.rack.RackResult
      def initialize(result)
        @status, @headers, @body = *result
      end
      
      def writeStatus(response)
        response.setStatus(@status.to_i)
      end
      
      def writeHeaders(response)
        @headers.each do |k,v|
          case k
          when /^Content-Type$/i
            response.setContentType(v.to_s)
          when /^Content-Length$/i
            response.setContentLength(v.to_i)
          else
            response.setHeader(k.to_s, v.to_s)
          end
        end
      end
      
      def writeBody(response)
        stream = response.getOutputStream
        @body.each do |el|
          stream.write(el.to_java_bytes)
        end
      end
    end

    class ServletLog
      def initialize(context = $servlet_context)
	@context = context
      end
      def puts(msg)
        write msg.to_s
      end
      def write(msg)
        @context.log(msg)
      end
      def flush; end
      def close; end
    end

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
        @logdev ||= ServletLog.new @servlet_context
      end

      def logger
	@logger ||= begin; require 'logger'; Logger.new(logdev); end
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

    class Errors
      def call(env)
        [500, {}, "Internal Server Error"]
      end
    end
  end
end