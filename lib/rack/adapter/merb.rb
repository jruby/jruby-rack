module Rack
  module Adapter

    class Merb
      def initialize
        if p = ::Merb::Server.config[:path_prefix]
          @path_prefix = /^#{Regexp.escape(p)}/
        end
      end

      def call(env)
        request = RequestWrapper.new(env)
        response = StringIO.new
        MERB_LOGGER.info("\nRequest: REQUEST_URI: #{request.params['REQUEST_URI']}  (#{Time.now.strftime("%Y-%m-%d %H:%M:%S")})")
        MERB_LOGGER.info("\nRequest: PATH_INFO: #{request.params['PATH_INFO']}  (#{Time.now.strftime("%Y-%m-%d %H:%M:%S")})")
        
        if @path_prefix
          if request.params['REQUEST_URI'] =~ @path_prefix
            request.params['PATH_INFO'].sub!(@path_prefix, '')
            request.params['REQUEST_URI'].sub!(@path_prefix, '')
          else
            raise "path.prefix is set to '#{@path_prefix.inspect}', but that's not in the REQUEST_URI. "
          end
        end

        begin
          controller, action = ::Merb::Dispatcher.handle(request, response)
        rescue Object => e
          return [500, {'Content-Type'=>'text/html'}, 'Internal Server Error: ' + e.to_s]
        end
        
        [controller.status, controller.headers, controller.body]
      end
    end
    
    class RequestWrapper
      def initialize(env); @env = env; end
      def params; @env; end
      def body; @env['rack.input']; end
    end
    
  end
end
