#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    def self.silence_warnings
      oldv, $VERBOSE = $VERBOSE, nil
      begin
        yield
      ensure
        $VERBOSE = oldv
      end
    end

    class Response
      include Java::org.jruby.rack.RackResponse
      def initialize(arr)
        @status, @headers, @body = *arr
      end
      
      def getStatus
        @status
      end

      def getHeaders
        @headers
      end

      def getBody
        b = ""
        @body.each {|part| b << part }
        b
      end
      
      def respond(response)
        if fwd = @headers["Forward"]
          fwd.call(response)
        else
          write_status(response)
          write_headers(response)
          write_body(response)
        end
      end

      def write_status(response)
        response.setStatus(@status.to_i)
      end
      
      def write_headers(response)
        @headers.each do |k,v|
          case k
          when /^Content-Type$/i
            response.setContentType(v.to_s)
          when /^Content-Length$/i
            response.setContentLength(v.to_i)
          else
            v.each {|val| response.addHeader(k.to_s, val) }
          end
        end
      end
      
      def write_body(response)
        stream = response.getOutputStream
        begin
          @body.each do |el|
            stream.write(el.to_java_bytes)
          end
        rescue LocalJumpError => e
          # HACK: deal with objects that don't comply with Rack specification
          @body = [@body.to_s]
          retry
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

    class ServletHelper
      attr_reader :public_root, :gem_path

      def initialize(servlet_context = nil)
        @servlet_context = servlet_context || $servlet_context
        @public_root = @servlet_context.getInitParameter 'public.root'
        @public_root ||= @servlet_context.getInitParameter 'files.prefix' # Goldspike
        @public_root ||= '/WEB-INF/public'
        @public_root = "/#{@public_root}" unless @public_root =~ %r{^/}
        @public_root = expand_root_path @public_root
        @public_root = @public_root.chomp("/")
        $0 = File.join(root_path, "web.xml")
        @gem_path = @servlet_context.getInitParameter 'gem.path'
        @gem_path ||= '/WEB-INF/gems'
        @gem_path = expand_root_path @gem_path
        setup_gems
        ServletHelper.instance = self
      end
      
      def root_path
        @root_path ||= real_path('/WEB-INF')
      end

      def real_path(path)
        @servlet_context.getRealPath(path)
      end

      def expand_root_path(path)
        if path =~ %r{^/WEB-INF}
          path.sub(%r{^/WEB-INF}, root_path)
        else
          real_path path
        end
      end

      def logdev
        @logdev ||= ServletLog.new @servlet_context
      end

      def logger
        @logger ||= begin; require 'logger'; Logger.new(logdev); end
      end

      def setup_gems
        $LOAD_PATH << 'META-INF/jruby.home/lib/ruby/site_ruby/1.8'
        ENV['GEM_PATH'] = @gem_path
      end

      def change_to_root_directory
        Dir.chdir(root_path)
      end

      def silence_warnings(&block)
        JRuby::Rack.silence_warnings(&block)
      end

      def self.instance
        @instance ||= self.new
      end

      def self.instance=(inst)
        @instance = inst
      end
    end

    class Errors
      EXCEPTION = org.jruby.rack.RackDispatcher::EXCEPTION
      def initialize(file_server)
        @file_server = file_server
      end

      def call(env)
        [code = response_code(env), *response_content(env, code)]
      end

      def response_code(env)
        exc = env[EXCEPTION]
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

      def response_content(env, code)
        @responses ||= Hash.new do |h,k|
          env["PATH_INFO"] = "/#{code}.html"
          response = @file_server.call(env)
          body = response[2]
          unless Array === body
            newbody = ""
            body.each do |chunk|
              newbody << chunk
            end
            response[2] = [newbody]
          end
          h[k] = response
        end
        response = @responses[code]
        if response[0] != 404
          env["rack.showstatus.detail"] = nil
          response[1..2]
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