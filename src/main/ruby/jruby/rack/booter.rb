#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby'
require 'jruby/rack'
require 'jruby/rack/app_layout'

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
      load_extensions
      self
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

    protected
    
    def silence_warnings(&block)
      JRuby::Rack.silence_warnings(&block)
    end

    def adjust_load_path
      # http://kenai.com/jira/browse/JRUBY_RACK-8 If some containers do
      # not allow proper detection of jruby.home, fall back to this
      tmpdir = java.lang.System.getProperty('java.io.tmpdir')
      if JRuby.runtime.instance_config.jruby_home == tmpdir
        ruby_paths = # mirroring org.jruby.runtime.load.LoadService#init
          if JRuby.runtime.is1_9
            %w{ site_ruby/1.9 site_ruby/shared site_ruby/1.8 1.9 }
          else
            %w{ site_ruby/1.8 site_ruby/shared 1.8 }
          end
        # NOTE: most servers end up with 'classpath:/...' entries :
        #  JRuby.home: "classpath:/META-INF/jruby.home"
        #  $LOAD_PATH:
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/1.9"
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/shared"
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/1.8"
        #   "classpath:/META-INF/jruby.home/lib/ruby/1.9"
        # seems to be the case for JBoss/Tomcat/WebLogic - it's best to
        # emulate the same setup for containers such as WebSphere where the
        # JRuby bootstrap fails to detect a correct home and points to /tmp
        # 
        # since JRuby 1.6.7 LoadService has better support for 'classpath:'
        # prefixed entries https://github.com/jruby/jruby-rack/issues/89
        #
        # also since JRuby 1.7.0 there's a fix for incorrect home detection
        # (avoids /tmp on IBM WAS) https://github.com/jruby/jruby/pull/123
        ruby_paths.each do |path|
          # NOTE: even better replace everything starting with '/tmp' ?
          if index = $LOAD_PATH.index("#{tmpdir}/lib/ruby/#{path}")
            $LOAD_PATH[index] = "classpath:/META-INF/jruby.home/lib/ruby/#{path}"
          else
            # e.g. "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/1.8"
            full_path = "classpath:/META-INF/jruby.home/lib/ruby/#{path}"
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

    def load_extensions
      require 'jruby/rack/rack_ext'
    end
    
    private
    
    def path_to_file(url)
      begin
        url.toURI.toString
      rescue java.net.URISyntaxException => e
        url.toString
      end
    end
  end
end
