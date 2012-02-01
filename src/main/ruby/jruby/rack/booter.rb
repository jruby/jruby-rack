#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby'

module JRuby::Rack
  class Booter
    attr_reader :rack_context

    def initialize(rack_context = nil)
      @rack_context = rack_context || $servlet_context
      @rack_env = ENV['RACK_ENV'] || @rack_context.getInitParameter('rack.env') || 'production'
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

    def adjust_load_path
      # http://kenai.com/jira/browse/JRUBY_RACK-8: If some containers do
      # not allow proper detection of jruby.home, fall back to this
      tmpdir = java.lang.System.getProperty('java.io.tmpdir')
      if JRuby.runtime.instance_config.jruby_home == tmpdir
        ruby_paths = # mirroring org.jruby.runtime.load.LoadService#init
          if JRuby.runtime.is1_9
            %w{ site_ruby/1.9 site_ruby/shared site_ruby/1.8 1.9 }
          else
            %w{ site_ruby/1.8 site_ruby/shared 1.8 }
          end
        ruby_paths.each do |path|
          # NOTE: even better replace everything starting with '/tmp' ?
          if index = $LOAD_PATH.index("#{tmpdir}/lib/ruby/#{path}")
            $LOAD_PATH[index] = "META-INF/jruby.home/lib/ruby/#{path}"
          else
            # e.g. "META-INF/jruby.home/lib/ruby/site_ruby/1.8"
            full_path = "META-INF/jruby.home/lib/ruby/#{path}"
            $LOAD_PATH << full_path unless $LOAD_PATH.include?(full_path)
          end
        end
      end
    end

    def load_settings_from_init_rb
      %w(META WEB).each do |where|
        url = @rack_context.getResource("/#{where}-INF/init.rb")
        next unless url
        code = 
          begin
            stream = url.openStream
            stream.to_io.read
          rescue Exception
            next
          ensure
            stream.close rescue nil
          end
        eval code, TOPLEVEL_BINDING, path_to_file(url)
      end
    end

    def path_to_file(url)
      begin
        url.toURI.toString
      rescue java.net.URISyntaxException => e
        url.toString
      end
    end
  end
end
