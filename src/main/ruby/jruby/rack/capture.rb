#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'stringio'

module JRuby::Rack
  module Capture
    module Base
      def output
        @output ||= begin; StringIO.new; end
      end

      def capture
        require 'rbconfig'
        servlet_context = JRuby::Rack.context
        output.puts("--- System", RUBY_DESCRIPTION, "Time: #{Time.now}",
                    "Server: #{servlet_context.getServerInfo}",
                    "jruby.home: #{RbConfig::CONFIG['prefix']}")
        output.puts("\n--- Context Init Parameters:",
                    *(servlet_context.init_parameter_names.sort.map do |k|
                        "#{k} = #{servlet_context.get_init_parameter(k)}"
                      end))
      end

      def store
        JRuby::Rack.context.log(output.string)
      end
    end

    module Exception
      def output
        @output ||= begin
          io = StringIO.new
          io.puts "An exception happened during JRuby-Rack startup", self.to_s
          io
        end
      end

      def capture
        super
        if backtrace
          require 'jruby'
          if JRuby.runtime.instance_config.respond_to?(:trace_type)
            full_trace = get_backtrace
          else
            full_trace = backtrace.join("\n")
          end
          output.puts("\n--- Backtrace", full_trace)
        end
      end

      private

      def get_backtrace
        if JRUBY_VERSION =~ /1\.6/
          JRuby.runtime.instance_config.trace_type.print_backtrace(self)
        else
          JRuby.runtime.instance_config.trace_type.print_backtrace(self, false)
        end
      end
    end

    module RubyGems
      def capture
        super
        if defined?(::Gem)
          output.puts("\n--- RubyGems", "Gem.dir: #{::Gem.dir}", "Gem.path:", ::Gem.path) rescue nil
          output.puts("Activated gems:", *(::Gem.loaded_specs.map {|_,spec| "  #{spec.full_name}" })) rescue nil
        end
      end
    end

    module Bundler
      def capture
        super
        if defined?(::Bundler)
          output.puts("\n--- Bundler")
          output.puts("Bundler.bundle_path: #{::Bundler.bundle_path}",
                      "Bundler.root: #{::Bundler.root}",
                      "Gemfile: #{::Bundler.default_gemfile}",
                      "Settings:", *(::Bundler.settings.all.map {|k| "  #{k} = #{::Bundler.settings[k]}" })) rescue output.puts($!)
        end
      end
    end

    module JRubyRackConfig
      def capture
        super
        servlet_context = JRuby::Rack.context
        methods = servlet_context.config.class.instance_methods(false) +
          org.jruby.rack.DefaultRackConfig.instance_methods(false)
        methods = methods.uniq.reject do |m|
          m =~ /^(get|is|set)/ || m =~ /[A-Z]|create|quiet|([!?=]$)/
        end
        output.puts("\n--- JRuby-Rack Config",
                    *(methods.sort.map do |m|
                        "#{m} = #{servlet_context.config.send(m)}" rescue "#{m} = <error: #{$?}>"
                      end))
      end
    end

    module Environment
      def capture
        super
        output.puts("\n--- Environment Variables", *(ENV.keys.sort.map do |k|
                                                  "#{k} = #{ENV[k]}"
                                                end))
      end
    end

    module JavaEnvironment
      def capture
        super
        output.puts("\n--- System Properties", *(ENV_JAVA.keys.sort.map do |k|
                                              "#{k} = #{ENV_JAVA[k]}"
                                            end))
      end
    end

    module LoadPath
      def capture
        super
        output.puts "\n--- $LOAD_PATH:", *$LOAD_PATH
      end
    end

    module Native
      def capture
        super
        output.puts "\n--- Java Exception"
        cause.printStackTrace java.io.PrintStream.new(output.to_outputstream)
      end
    end
  end
end
