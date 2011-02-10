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
        output.puts(RUBY_DESCRIPTION, "Time: #{Time.now}", "Server: #{$servlet_context.getServerInfo}",
                    "OS: #{Config::CONFIG['host_os']}", "jruby.home: #{Config::CONFIG['prefix']}")
        output.puts("Context Init Parameters:",
                    *($servlet_context.init_parameter_names.sort.map do |k|
                        "  #{k} = #{$servlet_context.get_init_parameter(k)}"
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
        output.puts "Backtrace:", *(backtrace.map {|t| "  #{t}"}) if backtrace
      end
    end

    module RubyGems
      def capture
        super
        if defined?(::Gem)
          output.puts("Gem.dir: #{Gem.dir}",
                      "Gem.path:", *(Gem.path.map{|path| "  #{path}"})) rescue nil
          output.puts("Activated gems:", *(Gem.loaded_specs.map {|spec| "  #{spec.full_name}" })) rescue nil
        end
      end
    end

    module Bundler
      def capture
        super
        if defined?(::Bundler)
          output.puts("Bundler.bundle_path: #{Bundler.bundle_path}",
                      "Bundler.root: #{Bundler.root}",
                      "Gemfile: #{Bundler.default_gemfile}",
                      "Settings:", *(Bundler.settings.all.map {|k| "  #{Bundler.settings[k]}" })) rescue nil
        end
      end
    end

    module LoadPath
      def capture
        super
        output.puts "$LOAD_PATH:", *($LOAD_PATH.map{|lp| "  #{lp}"})
      end
    end

    module Native
      def capture
        super
        output.puts "Java Exception: #{cause.toString}"
      end
    end
  end
end
