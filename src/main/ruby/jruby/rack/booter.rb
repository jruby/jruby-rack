#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack'
require 'jruby/rack/app_layout'

module JRuby::Rack
  class Booter
    attr_reader :rack_context, :rack_env

    def initialize(rack_context = nil)
      @rack_context = rack_context || JRuby::Rack.context || raise("rack context not available")
      @rack_env = ENV['RACK_ENV'] || @rack_context.getInitParameter('rack.env') || 'production'
    end

    def boot!
      adjust_load_path
      ENV['RACK_ENV'] = rack_env
      gem_path = layout.gem_path
      if env_gem_path = ENV['GEM_PATH']
        if gem_path.nil? || gem_path.empty?
          gem_path = env_gem_path # keep ENV['GEM_PATH'] as is
        elsif env_gem_path != gem_path
          gem_path = "#{gem_path}#{File::PATH_SEPARATOR}#{env_gem_path}"
        end
      end
      ENV['GEM_PATH'] = gem_path
      export_global_settings
      change_working_directory
      load_settings_from_init_rb
      load_extensions
      self
    end
    
    def default_layout_class
      klass = @rack_context.getInitParameter 'jruby.rack.layout_class'
      klass.nil? ? WebInfLayout : eval(klass) # TODO really eval ?!
    end

    def layout_class
      @layout_class ||= default_layout_class
    end
    attr_writer :layout_class

    def layout
      @layout ||= layout_class.new(@rack_context)
    end
    attr_writer :layout

    %w( app_path gem_path public_path ).each do |path|
      # def app_path; layout.app_path; end
      # def app_path=(path); layout.app_path = path; end
      class_eval "def #{path}; layout.#{path}; end"
      class_eval "def #{path}=(path); layout.#{path} = path; end"
    end

    # #deprecated use JRuby::Rack.logger
    def logger
      JRuby::Rack.logger
    end

    protected

    def export_global_settings
      JRuby::Rack.send(:instance_variable_set, :@booter, self) # TODO
      JRuby::Rack.app_path = layout.app_path
      JRuby::Rack.public_path = layout.public_path
    end
    
    def change_working_directory
      app_path = layout.app_path
      Dir.chdir(app_path) if app_path && File.directory?(app_path)
    end
    
    def adjust_load_path
      require 'jruby'
      # http://kenai.com/jira/browse/JRUBY_RACK-8 If some containers do
      # not allow proper detection of jruby.home, fall back to this
      tmpdir = java.lang.System.getProperty('java.io.tmpdir')
      if JRuby.runtime.instance_config.jruby_home == tmpdir
        ruby_paths = # mirroring org.jruby.runtime.load.LoadService#init
          if JRUBY_VERSION >= '1.7.0'
            # 2.0 is 1.9 as well and uses the same setup as 1.9 currently ...
            %w{ site_ruby shared } << ( JRuby.runtime.is1_9 ? '1.9' : '1.8' )
          else # <= JRuby 1.6.8
            if JRuby.runtime.is1_9
              %w{ site_ruby/1.9 site_ruby/shared site_ruby/1.8 1.9 }
            else
              %w{ site_ruby/1.8 site_ruby/shared 1.8 }
            end
          end
        # NOTE: most servers end up with 'classpath:/...' entries :
        #  JRuby.home: "classpath:/META-INF/jruby.home"
        #  $LOAD_PATH (JRuby 1.6.8 --1.9):
        # 
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/1.9"
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/shared"
        #   "classpath:/META-INF/jruby.home/lib/ruby/site_ruby/1.8"
        #   "classpath:/META-INF/jruby.home/lib/ruby/1.9"
        # 
        #  $LOAD_PATH (JRuby 1.7.0):
        #
        #   classpath:/META-INF/jruby.home/lib/ruby/site_ruby (missing dir)
        #   classpath:/META-INF/jruby.home/lib/ruby/shared
        #   classpath:/META-INF/jruby.home/lib/ruby/1.9
        # 
        # seems to be the case for JBoss/Tomcat/WebLogic - it's best to
        # emulate the same setup for containers such as WebSphere where the
        # JRuby bootstrap fails to detect a correct home and points to /tmp
        # 
        # since JRuby 1.6.7 LoadService has better support for 'classpath:'
        # prefixed entries https://github.com/jruby/jruby-rack/issues/89
        #
        # also since JRuby 1.7.0 there's a fix for incorrect home detection
        # (avoids /tmp on IBM WAS) https://github.com/jruby/jruby/pull/123
        #
        ruby_paths.each do |path|
          # NOTE: even better replace everything starting with '/tmp' ?
          if index = $LOAD_PATH.index("#{tmpdir}/lib/ruby/#{path}")
            $LOAD_PATH[index] = "classpath:/META-INF/jruby.home/lib/ruby/#{path}"
          else
            # e.g. "classpath:/META-INF/jruby.home/lib/ruby/1.8"
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
          rescue Exception => e
            logger.info "failed to read from '#{url.toString}' (#{e.message})"
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
    
    def silence_warnings(&block)
      Helpers.silence_warnings(&block)
    end
    
    def path_to_file(url)
      begin
        url.toURI.toString
      rescue java.net.URISyntaxException
        url.toString
      end
    end
    
  end
end
