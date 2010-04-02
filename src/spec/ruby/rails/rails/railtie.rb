module Rails
  # A mock Railtie class for specs to use
  class Railtie
    def self.initializer(name, *options, &block)
      self.initializers << [name, options, block]
    end

    def self.initializers
      @@initializers ||= []
    end
  end
end
