module Rails
  class Initializer
    def self.run(method = :process)
      initializer = new
      initializer.send(method)
      initializer
    end

    def set_load_path
    end

    def process
      require_frameworks
    end

    def require_frameworks
      require 'action_controller'
    end
  end
end