module Rails
  # A mock Railtie class for specs to use
  class Railtie
    def self.railtie_name(nm)
      @name = nm
    end

    def self.config
      @@config
    end

    def self.config=(conf)
      @@config = conf
    end

    def self.initializer(name, *options, &block)
      self.initializers << [name, options, block]
    end

    def self.initializers
      @@initializers ||= []
    end
  end
end
