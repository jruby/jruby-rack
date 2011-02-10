#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  module Capture
    module Base
      def output
        @output ||= begin; require 'stringio'; StringIO.new; end
      end

      def capture
        require 'rbconfig'
        output.puts("--- System", RUBY_DESCRIPTION, "Time: #{Time.now}",
                    "Server: #{$servlet_context.getServerInfo}",
                    "jruby.home: #{Config::CONFIG['prefix']}")
        output.puts("\n--- Context Init Parameters:",
                    *($servlet_context.init_parameter_names.sort.map do |k|
                        "#{k} = #{$servlet_context.get_init_parameter(k)}"
                      end))
      end

      def store
        $servlet_context.log(output.string)
      end
    end

    module Exception
      def output
        @output ||= begin; require 'stringio'; StringIO.new.tap do |s|
            s.puts "An exception happened during JRuby-Rack startup", self.to_s
          end; end
      end

      def capture
        super
        output.puts("\n--- Backtrace", *backtrace) if backtrace
      end
    end

    module RubyGems
      def capture
        super
        if defined?(::Gem)
          output.puts("\n--- RubyGems", "Gem.dir: #{Gem.dir}", "Gem.path:", Gem.path) rescue nil
          output.puts("Activated gems:", *(Gem.loaded_specs.map {|k,spec| "  #{spec.full_name}" })) rescue nil
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
