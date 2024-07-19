#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'

module JRuby
  module Rack
    class ErrorApp

      autoload :ShowStatus, 'jruby/rack/error_app/show_status'

      # @private
      InterruptedException = Java::JavaLang::InterruptedException

      EXCEPTION = org.jruby.rack.RackEnvironment::EXCEPTION
      DEFAULT_EXCEPTION_DETAIL = ''

      DEFAULT_RESPONSE_CODE = 500
      DEFAULT_MIME = 'text/plain'
      DEFAULT_HEADERS = {}

      UNAVAILABLE_EXCEPTIONS = [
        org.jruby.rack.AcquireTimeoutException,
        # org.jruby.rack.RackInitializationException
      ]

      ALLOW_METHODS = 'HEAD, GET, POST, PUT, DELETE, OPTIONS'

      attr_reader :root

      def initialize(root = nil)
        if defined?(::Rack::File) && root.is_a?(::Rack::File)
          @root = root.root # backwards compatibility
        else
          @root = root.nil? ? JRuby::Rack.public_path : root
          @root = nil if @root && ! File.directory?(@root)
        end
      end

      def call(env)
        if env['REQUEST_METHOD'] == 'OPTIONS'
          return [ 200, {'Allow' => ALLOW_METHODS, 'Content-Length' => '0'}, [] ]
        end

        code = response_code(env)

        return respond(code) if ! root || ! accept_html?(env)

        # TODO support custom JSON/XML 5xx and better HTTP_ACCEPT matching
        # NOTE: code == 503 ... we're try 503.html and fallback to 500.html
        if ! code || ! path = expand_path("/#{code}.html")
          code ||= DEFAULT_RESPONSE_CODE
          path = expand_path("/#{DEFAULT_RESPONSE_CODE}.html")
          code = DEFAULT_RESPONSE_CODE if path
        end

        path ? serve(code, path, env) : respond(code)
      end

      def response_code(env)
        if exc = env[EXCEPTION]
          unless env.key?(key = 'rack.showstatus.detail')
            begin
              env[key] = exc.message || DEFAULT_EXCEPTION_DETAIL
            rescue => e
              env[key] = DEFAULT_EXCEPTION_DETAIL
              warn e.inspect
            end
          end
          map_error_code(exc)
        else
          nil
        end
      end

      def serve(code, path, env)
        last_modified = File.mtime(path).httpdate
        return [ 304, {}, [] ] if env['HTTP_IF_MODIFIED_SINCE'] == last_modified

        headers = { 'Last-Modified' => last_modified }
        DEFAULT_HEADERS.each { |field, content| headers[field] = content }
        ext = File.extname(path)
        size = File.size?(path)
        mime = ::Rack::Mime.mime_type(ext, DEFAULT_MIME) if defined?(::Rack::Mime)
        mime = 'text/html' if ! mime && ( ext == '.html' || ext == '.htm' )
        headers['Content-Type'] = mime if mime

        body = env['REQUEST_METHOD'] == 'HEAD' ? [] : FileBody.new(path, size)
        response = [ code, headers, body ]

        response[1]['Content-Length'] = size.to_s if size
        response
      end

      protected

      def map_error_code(exc)
        if UNAVAILABLE_EXCEPTIONS.any? { |type| exc.kind_of?(type) }
          503 # Service Unavailable
        elsif exc.respond_to?(:cause) && exc.cause.kind_of?(InterruptedException)
          503 # Service Unavailable
        else
          500
        end
      end

      def respond(status = nil, body = nil, headers = DEFAULT_HEADERS)
        status ||= DEFAULT_RESPONSE_CODE
        body += "\n" if body
        headers['Content-Type'] = "text/plain" unless headers.key?('Content-Type')
        headers['Content-Length'] = body.size.to_s if ! headers.key?('Content-Length') && body
        headers['X-Cascade'] = "pass" unless headers.key?('X-Cascade')
        [ status, headers, body ? [ body ] : [] ]
      end

      class FileBody

        CHUNK_SIZE = 8192

        attr_reader :path, :size
        alias to_path path

        def initialize(path, size = nil); @path = path; @size = size end

        def each
          File.open(@path, "rb") do |file|
            # file.seek(0)
            remaining = @size || (1.0 / 0)
            chunk_size = CHUNK_SIZE
            while remaining > 0
              chunk_size = remaining if remaining < chunk_size
              break unless part = file.read(chunk_size)
              remaining -= part.length

              yield part
            end
          end
        end

      end

      private

      def expand_path(path, root = self.root)
        exp_path = File.join(root, path)
        begin
          return exp_path if File.file?(exp_path) && File.readable?(exp_path)
        rescue SystemCallError
          nil
        end
      end

      begin
        require 'rack/utils'
        Utils = ::Rack::Utils

        if ''.respond_to?(:bytesize) # Ruby >= 1.9
          def Utils.bytesize(string); string.bytesize end
        else
          def Utils.bytesize(string); string.size end
        end unless defined? Utils.bytesize

        require 'rack/mime'
      rescue LoadError; end

      if defined? Utils.best_q_match

        def accepts_html?(env)
          Utils.best_q_match(env['HTTP_ACCEPT'], %w[text/html])
        rescue
          http_accept?(env, 'text/html')
        end

      else

        def accepts_html?(env)
          http_accept?(env, 'text/html') || http_accept?(env, '*/*')
        end

      end
      alias accept_html? accepts_html? # JRuby-Rack 1.1 compatibility

      def http_accept?(env, mime)
        http_accept = env['HTTP_ACCEPT'].to_s
        http_accept.empty? ? nil : !! http_accept.index(mime)
      end

    end
  end
end
