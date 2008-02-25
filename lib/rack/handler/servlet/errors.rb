module Rack
  module Handler
    class Servlet
      class Errors
        def call(env)
          [500, {}, "Internal Server Error"]
        end
      end
    end
  end
end