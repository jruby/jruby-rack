#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  class Booter
    attr_reader :rack_context

    def initialize(rack_context = nil)
      @rack_context = rack_context || $servlet_context
      @rack_env = @rack_context.getInitParameter('rack.env') || 'production'
      JRuby::Rack.booter = self
    end

    def boot!
      adjust_load_path
      ENV['RACK_ENV'] = @rack_env
      if ENV['GEM_PATH']
        ENV['GEM_PATH'] = layout.gem_path + File::PATH_SEPARATOR + ENV['GEM_PATH']
      else
        ENV['GEM_PATH'] = layout.gem_path
      end
      load_settings_from_init_rb
      layout.change_working_directory if layout.respond_to?(:change_working_directory)
      require 'vendor/rack' unless defined?(::Rack::VERSION) # already loaded?
    end

    def default_layout_class
      c = @rack_context.getInitParameter 'jruby.rack.layout_class'
      c.nil? ? WebInfLayout : eval(c)
    end

    def layout_class
      @layout_class ||= default_layout_class
    end

    def layout_class=(c)
      @layout_class = c
    end

    def layout
      @layout ||= layout_class.new(@rack_context)
    end

    %w(app_path gem_path public_path).each do |m|
      # def app_path; layout.app_path; end
      # def app_path=(v); layout.app_path = v; end
      class_eval "def #{m}; layout.#{m}; end"
      class_eval "def #{m}=(v); layout.#{m} = v; end"
    end

    def logdev
      @logdev ||= ServletLog.new @rack_context
    end

    def logger
      @logger ||= begin; require 'logger'; Logger.new(logdev); end
    end

    def silence_warnings(&block)
      JRuby::Rack.silence_warnings(&block)
    end

    # http://kenai.com/jira/browse/JRUBY_RACK-8: If some containers do
    # not allow proper detection of jruby.home, fall back to this
    def adjust_load_path
      require 'jruby'
      if JRuby.runtime.instance_config.jruby_home == java.lang.System.getProperty('java.io.tmpdir')
        $LOAD_PATH << 'META-INF/jruby.home/lib/ruby/site_ruby/1.8'
        $LOAD_PATH << 'META-INF/jruby.home/lib/ruby/1.8'
        $LOAD_PATH << 'META-INF/jruby.home/lib/ruby/site_ruby/shared'
      end
    end

    def load_settings_from_init_rb
      %w(META WEB).each do |where|
        url = @rack_context.getResource("/#{where}-INF/init.rb")
        next unless url
        code = begin
                 stream = url.openStream
                 stream.to_io.read
               rescue Exception
                 next
               ensure
                 stream.close rescue nil
               end
        logger.info("* Loading from #{url.path}:\n#{code}") if LoadPathDebugging.enabled?
        eval code, nil, url.path
      end
    end
  end
end
