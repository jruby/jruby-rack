#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rails
  # A mock Railtie class for specs to use
  class Railtie
    
    class << self

      def config
        instance.config
      end
      
      def instance
        @instance ||= new
      end

      def respond_to?(*args)
        super || instance.respond_to?(*args)
      end

      def configure(&block)
        class_eval(&block)
      end

      protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
      
    end
    
    def config
      @config ||= Configuration.new
    end
    
    class Configuration
      
      def initialize
        @@options ||= {}
      end

      def respond_to?(name)
        super || @@options.key?(name.to_sym)
      end

      # First configurable block to run. Called before any initializers are run.
      def before_configuration(&block)
        __before_configuration << block
      end

      # Third configurable block to run. Does not run if config.cache_classes
      # set to false.
      def before_eager_load(&block)
        __before_eager_load << block
      end

      # Second configurable block to run. Called before frameworks initialize.
      def before_initialize(&block)
        __before_initialize << block
      end

      # Last configurable block to run. Called after frameworks initialize.
      def after_initialize(&block)
        __after_initialize << block
      end
      
      @@__before_configuration = nil
      def __before_configuration # for tests
        @@__before_configuration ||= []
      end

      @@__before_eager_load = nil
      def __before_eager_load # for tests
        @@__before_eager_load ||= []
      end

      @@__before_initialize = nil
      def __before_initialize # for tests
        @@__before_initialize ||= []
      end

      @@__after_initialize = nil
      def __after_initialize # for tests
        @@__after_initialize ||= []
      end
      
      private

      def method_missing(name, *args, &blk)
        if name.to_s =~ /=$/
          @@options[$`.to_sym] = args.first
        elsif @@options.key?(name)
          @@options[name]
        else
          super
        end
      end
      
    end
    
    def self.initializer(name, *options, &block)
      __initializer << [ name, options, block ]
    end

    @@__initializer = nil
    def self.__initializer # for tests
      @@__initializer ||= []
    end
    
    def self.__clear # for tests
      __initializer.clear
      config.__before_configuration.clear
      config.__before_eager_load.clear
      config.__before_initialize.clear
      config.__after_initialize.clear
    end
    
  end
end
