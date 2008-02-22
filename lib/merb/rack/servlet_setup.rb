module Merb
  module Rack
    class ServletSetup
      def initialize(app)
        @app = app
      end

      def call(env)
        # Read the entire request body up front
        env['rack.input'] = StringIO.new(env['rack.input'].read)
        @app.call(env)
      end
    end
  end
end