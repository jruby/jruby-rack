module Rack
  module Adapter

    class Merb
      def call(env)
        request = RequestWrapper.new(env)
        response = StringIO.new
        begin 
          controller, action = Merb::Dispatcher.handle(request, response)
        rescue Object => e
          return [500, {'Content-Type'=>'text/html'}, 'Internal Server Error']
        end
        
        [controller.status, controller.headers, controller.body]
      end 
      
      class RequestWrapper
        def initialize(env); @env = env; end
        def params; @env; end
        def body; @env['rack.input']; end
      end
    end
    
  end
end
