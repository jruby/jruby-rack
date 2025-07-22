#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    module Helpers
    
      module_function

      # Silence (... I'll kill you!)
      def silence_warnings
        verbose, $VERBOSE = $VERBOSE, nil
        begin
          yield
        ensure
          $VERBOSE = verbose
        end
      end
      
      UNDERSCORE_CONVERSIONS = { 'JRuby' => 'jruby' }
      
      # Makes an underscored, lowercase form from the expression in the string.
      #
      # Changes '::' to '/' to convert namespaces to paths.
      # 
      # Treats the JRuby name specially mapping it to the "jruby" path (prefix).
      #
      # Examples:
      #   underscore("DefaultEnv") # => "default_env"
      #   underscore("Rack::Handler::Servlet") # => "rack/handler/servlet"
      #   underscore("JRuby::Rack") # => "jruby/rack"
      #   underscore("JRubyJars") # => "jruby_jars"
      #
      def underscore(camel_cased_name, conversions = true)
        conversions = UNDERSCORE_CONVERSIONS if conversions == true
        word = camel_cased_name.to_s.strip.split('::')
        if conversions
          word.each do |w|
            if replace = conversions[w]
              w.replace(replace.dup)
            elsif m = w.match(/^([A-Z\d]+)([A-Z][a-z]+)(.*)$/)
              replace = conversions["#{m[1]}#{m[2]}"] || "#{m[1]}_#{m[2]}"
              replace += m[3].gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
              w.replace(replace)
            else
              w.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
            end
          end
        else
          word.each { |w| w.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2') }
        end
        word = word.join('/')
        word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        word.tr!('-', '_')
        word.downcase!
        word
      end
      
      # Tries to find a constant with the name specified in the argument string.
      #
      #   constantize(:Module) # => Module
      #   constantize('Math::PI') # => Math::PI
      #
      # The name is assumed to be the one of a top-level constant, no matter
      # whether it starts with "::" or not. No lexical context is taken into
      # account:
      #
      #   C = 'outside'
      #   module M
      #     C = 'inside'
      #     C # => 'inside'
      #     'C'.constantize # => 'outside', same as ::C
      #   end
      #
      # NameError raised when the name is not CamelCase or the constant is unknown.
      def constantize(camel_cased_name, context = Object)
        names = camel_cased_name.to_s.strip.split('::')
        if names.first && names.first.empty?
          names.shift; context = Object # ::Constant
        end
        
        names.inject(context) do |constant, name|
          if constant == Object
            constant.const_get(name)
          else
            if constant.const_defined?(name, *CONST_DEF_ARG) ||
                ! Object.const_defined?(name)
              begin
                next constant.const_get(name)
              rescue ArgumentError => e
                if e.message.index 'is not missing constant'
                  raise NameError, e.message
                else
                  raise e
                end
              end
            end
            
            # Go down the ancestors to check it it's owned
            # directly before we reach Object or the end of ancestors.
            constant = constant.ancestors.inject do |const, ancestor|
              break const if ancestor == Object
              break ancestor if ancestor.const_defined?(name, *CONST_DEF_ARG)
              const
            end
            
            constant.const_get(name)
          end
        end
      end

      CONST_DEF_ARG = (Module.method(:const_defined?).arity != 1 ? [false] : []).freeze # :nodoc
      
      # Resolve a constant given as a camel cased name.
      # Does #constantize but it the constant is not found it tried loading
      # it by converting the name to #underscore and requiring that feature.
      #
      #   resolve_constant 'JRuby::Rack::Worker'
      # 
      # 1. checks for the JRuby::Rack::Worker constant
      # 2. since it's missing requires 'jruby/rack/worker'
      # 3. checks for the JRuby::Rack::Worker again ...
      # 
      # NameError raised when the constant is unknown (LoadError gets swallowed).
      def resolve_constant(camel_cased_name, context = Object)
        required = nil
        begin
          constantize(camel_cased_name, context)
        rescue NameError => e
          begin
            required = true
            require underscore(camel_cased_name)
            retry
          rescue LoadError => le
            e.message = "#{e.message} (#{le.message})"
          end unless required
          raise e
        end
      end
      
    end
  end
end