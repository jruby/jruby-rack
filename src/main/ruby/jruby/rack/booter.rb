#--
# Copyright (c) 2012-2016 Karol Bucek, LTD.
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/app_layout'

module JRuby::Rack
  # A (generic) booter responsible for racking-up `Rack` applications.
  # @note a single instance of a `JRuby::Rack::Booter` is expected to be created
  # and boot-ed within a single JRuby-Rack managed (Ruby) runtime.
  class Booter

    @@boot_hooks = []

    # Allows the define a on (load) hook to be executed during the boot.
    # These hooks are expected to execute when the application is fully loaded.
    # Thus e.g. in Rails they might be delayed until the actual Rails boot
    # process is finishing up.
    def self.on_boot(options = {}, &block)
      if @@boot_hooks.nil? # run immediately
        base = options[:base] || ::Rack
        run_boot_hook(base, options, block)
      else
        @@boot_hooks << [ block, options ]
      end
    end

    # Manually execute the given (load) hook.
    # Called for all hooks during {#run_boot_hooks!}.
    # @see #on_boot
    def self.run_boot_hook(base, options, block)
      options[:yield] ? block.call(base) : base.instance_eval(&block)
    end

    # Runs all registered load hooks (and clear them out than).
    # It's safe to call this multiple times - hooks will only execute once.
    # @see #on_boot
    def self.run_boot_hooks!(base = nil)
      return if @@boot_hooks.nil?
      load_hooks = @@boot_hooks; @@boot_hooks = nil
      load_hooks.each do |hook, options|
        hook_base = base || options[:base] || ::Rack
        run_boot_hook(hook_base, options, hook)
      end
    end

    attr_reader :rack_context, :rack_env

    def initialize(rack_context = nil)
      @rack_context = rack_context || JRuby::Rack.context || raise("rack context not available")
      @rack_env = ENV['RACK_ENV'] || @rack_context.getInitParameter('rack.env') || 'production'
    end

    # @return [Class] the (default) layout class to use
    # @see #layout_class
    def self.default_layout_class; WebInfLayout; end
    # @deprecated use the class method
    def default_layout_class; self.class.default_layout_class; end

    # @return [Class] the layout class to use
    # @see #layout
    def layout_class
      @layout_class ||= begin
        klass = @rack_context.getInitParameter 'jruby.rack.layout_class'
        klass.nil? ? self.class.default_layout_class : Helpers.resolve_constant(klass, JRuby::Rack)
      end
    end
    attr_writer :layout_class

    # Returns an application layout instance (for this booter's application).
    # @return [JRuby::Rack::AppLayout]
    def layout
      @layout ||= layout_class.new(@rack_context)
    end
    attr_writer :layout

    def app_path; layout.app_path end
    def app_path=(path); layout.app_path = path end
    def gem_path; layout.gem_path end
    def gem_path=(path); layout.gem_path = path end
    def public_path; layout.public_path end
    def public_path=(path); layout.public_path = path end

    # @deprecated use {JRuby::Rack#logger} instead
    # @return [Logger]
    def logger; JRuby::Rack.logger; end

    # Boot-up this booter, preparing the environment for the application.
    def boot!
      adjust_load_path
      adjust_gem_path
      ENV['RACK_ENV'] = rack_env
      export_global_settings
      change_working_directory
      load_settings_from_init_rb
      set_relative_url_root
      run_boot_hooks
      self
    end

    protected

    def adjust_gem_path
      gem_path = self.gem_path
      case set_gem_path = env_gem_path
      when true then
        if env_path = ENV['GEM_PATH']
          if gem_path.nil? || gem_path.empty?
            return # keep ENV['GEM_PATH'] as is
          elsif env_path != gem_path
            separator = File::PATH_SEPARATOR
            unless env_path.split(separator).include?(gem_path)
              ENV['GEM_PATH'] = "#{gem_path}#{separator}#{env_path}"
            end
          end
        else
          ENV['GEM_PATH'] = gem_path
        end
      when false then
        begin
          require 'rubygems' unless defined? Gem.path
        rescue LoadError
        else
          return if gem_path.nil? || gem_path.empty?
          Gem.path.unshift(gem_path) unless Gem.path.include?(gem_path)
        end
        return false
      when nil then # org.jruby.rack.RackLogger::DEBUG
        if gem_path && ! gem_path.empty? &&
          ( ! defined?(Gem.path) || ! Gem.path.include?(gem_path) )
          @rack_context.log("Gem.path won't be updated although seems configured: #{gem_path}")
        end
        return nil
      else # 'jruby.rack.env.gem_path' "forced" to an explicit value
        ENV['GEM_PATH'] = set_gem_path
      end
    end

    # @return whether to update Gem.path and/or the environment GEM_PATH
    # - true (default) forces ENV['GEM_PATH'] to be updated due compatibility
    #   Bundler 1.6 fails to revolve gems correctly when Gem.path is updated
    #   instead of the ENV['GEM_PATH'] environment variable
    # - false disables ENV['GEM_PATH'] mangling for good (updates Gem.path)
    #
    # - if not specified Gem.path will be updated based on setting
    def env_gem_path
      gem_path = @rack_context.getInitParameter('jruby.rack.env.gem_path')
      return true if gem_path.nil? || gem_path.to_s == 'true'
      return false if gem_path.to_s == 'false'
      return nil if gem_path.empty? # set to an empty disables mangling
      gem_path
    end
    private :env_gem_path

    # @note called during {#boot!}
    def export_global_settings
      JRuby::Rack.send(:instance_variable_set, :@booter, self) # TODO
      JRuby::Rack.app_path = layout.app_path
      JRuby::Rack.public_path = layout.public_path
    end

    # Changes the working directory (`Dir.chdir`) is necessary.
    # @note called during {#boot!}
    def change_working_directory
      app_path = layout.app_path
      if app_path && File.directory?(app_path)
        Dir.chdir(app_path) rescue nil # Errno::ENOENT
      end
    end

    # Adjust the load path (mostly due some J2EE servers slightly misbehaving).
    # @note called during {#boot!}
    def adjust_load_path
      require 'jruby'
      # http://kenai.com/jira/browse/JRUBY_RACK-8 If some containers do
      # not allow proper detection of jruby.home, fall back to this
      tmpdir = ENV_JAVA['java.io.tmpdir']
      if tmpdir && JRuby.runtime.jruby_home == tmpdir
        ruby_paths = # mirroring org.jruby.runtime.load.LoadService#init
          if JRUBY_VERSION >= '9.0.0'
            # "/opt/local/rvm/rubies/jruby-9.0.4.0/lib/ruby/2.2/site_ruby"
            # "/opt/local/rvm/rubies/jruby-9.0.4.0/lib/ruby/stdlib"
            %W{ #{RUBY_VERSION[0, 3]}/site_ruby stdlib }
          elsif JRUBY_VERSION >= '1.7.0'
            if (JRuby.runtime.is2_0 rescue nil)
              %w{ site_ruby shared 2.0 1.9 }
            else
              %w{ site_ruby shared } << ( JRuby.runtime.is1_9 ? '1.9' : '1.8' )
            end
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

    # Checks for *META-INF/init.rb* and *WEB-INF/init.rb* code and evals it.
    # These init files are assumed to contain user supplied initialization code
    # to be loaded and executed during {#boot!}.
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

    # @deprecated no longer used, replaced with {#run_boot_hooks}
    def load_extensions
      run_boot_hooks
    end

    def relative_url_root(init_param = 'rack.relative_url_append')
      relative_url_root = @rack_context.getContextPath || ''
      if relative_url_append = @rack_context.getInitParameter(init_param)
        relative_url_root = File.join(relative_url_root, relative_url_append)
      end
      relative_url_root.empty? || relative_url_root == '/' ? nil : relative_url_root
    end

    def set_relative_url_root
      if rack_relative_url_root = relative_url_root('rack.relative_url_append')
        if env_var = @rack_context.getInitParameter('rack.relative_url_root_variable')
          ENV[env_var] = rack_relative_url_root
        end
      end
    end

    # Runs the "global" registered boot hooks by default.
    # @note called (just) before {#boot!} finishes
    # @see JRuby::Rack::Booter#run_boot_hooks!
    def run_boot_hooks
      self.class.run_boot_hooks!
    end

    def real_path(path); layout.real_path(path) end
    def expand_path(path); layout.expand_path(path) end

    private

    def silence_warnings(&block)
      Helpers.silence_warnings(&block)
    end

    def path_to_file(url)
      url.toURI.toString
    rescue Java::JavaNet::URISyntaxException
      url.toString
    end

  end
end
