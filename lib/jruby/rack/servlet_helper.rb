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
      EXCEPTION = org.jruby.rack.RackServlet::EXCEPTION
      def initialize(file_server)
	@file_server = file_server
      end

      def call(env)
        [code = result_code(env), *result_content(env, code)]
      end

      def result_code(env)
        exc = env['java.servlet_request'].getAttribute(EXCEPTION)
        if exc 
          env['rack.showstatus.detail'] = exc.getMessage
          if exc.getCause.kind_of?(Java::JavaLang::InterruptedException)
            503
          else
            500
          end
        else
          500
        end
      end

      def result_content(env, code)
        @results ||= Hash.new do |h,k|
          env["PATH_INFO"] = "/#{code}.html"
          result = @file_server.call(env)
          body = result[2]
          unless Array === body
            newbody = ""
            body.each do |chunk|
              newbody << chunk
            end
            result[2] = [newbody]
          end
          h[k] = result
        end
        result = @results[code]
        if result[0] != 404
          env["rack.showstatus.detail"] = nil
          result[1..2]
        else
          [{}, []]
        end
      end
    end

    class ErrorsApp
      def self.new
        ::Rack::Builder.new {
          use ::Rack::ShowStatus
          run Errors.new(::Rack::File.new(ServletHelper.instance.public_root))
        }.to_app
      end
    end
  end
end