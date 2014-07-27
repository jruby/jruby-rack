#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'

module JRuby
  module Rack
    class ErrorApp

      EXCEPTION = org.jruby.rack.RackEnvironment::EXCEPTION

      DEFAULT_RESPONSE_CODE = 500
      DEFAULT_MIME = 'text/plain'
      DEFAULT_HEADERS = {}

      UNAVAILABLE_EXCEPTIONS = [
        org.jruby.rack.AcquireTimeoutException,
        # org.jruby.rack.RackInitializationException
      ]

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
          allow_methods = 'HEAD, GET, POST, PUT, DELETE, OPTIONS'
          return [ 200, {'Allow' => allow_methods, 'Content-Length' => '0'}, [] ]
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
          env['rack.showstatus.detail'] = exc.message rescue ''
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
        mime = ::Rack::Mime.mime_type(ext, DEFAULT_MIME) if defined?(::Rack::Mime)
        mime = 'text/html' if ! mime && ( ext == '.html' || ext == '.htm' )
        headers['Content-Type'] = mime if mime

        body = env['REQUEST_METHOD'] == 'HEAD' ? [] : FileBody.new(path, size = File.size?(path))
        response = [ code, headers, body ]

        size ||= ::Rack::Utils.bytesize(File.read(path)) if defined?(::Rack::Utils)

        response[1]['Content-Length'] = size.to_s if size
        response
      end

      private

      def accept_html?(env)
        http_accept = env['HTTP_ACCEPT'].to_s
        if ! http_accept.empty? # NOTE: some really stupid matching for now :
          !! ( http_accept.index('text/html') || http_accept.index('*/*') )
        else
          nil
        end
      end

      def map_error_code(exc)
        cause = exc.respond_to?(:cause) ? exc.cause : nil
        if UNAVAILABLE_EXCEPTIONS.any? { |type| exc.kind_of?(type) }
          503 # Service Unavailable
        elsif cause.kind_of?(Java::JavaLang::InterruptedException)
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

      def expand_path(path, root = self.root)
        exp_path = File.join(root, path)
        begin
          return exp_path if File.file?(exp_path) && File.readable?(exp_path)
        rescue SystemCallError
          nil
        end
      end

      class FileBody

        attr_reader :path, :size
        alias to_path path

        def initialize(path, size = nil); @path = path; @size = size end

        def each
          File.open(@path, "rb") do |file|
            # file.seek(0)
            remaining = @size || (1.0 / 0)
            chunk_size = 8192
            while remaining > 0
              chunk_size = remaining if remaining < chunk_size
              break unless part = file.read(chunk_size)
              remaining -= part.length

              yield part
            end
          end
        end

      end

      def self.silent_require(feature)
        require feature
      rescue LoadError
        nil
      end

      silent_require 'rack/utils'
      silent_require 'rack/mime'

    end
  end
end