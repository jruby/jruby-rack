#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  class Booter
    def initialize(rack_context = nil)
      @rack_context = rack_context || $servlet_context
      JRuby::Rack.booter = self
    end

    def boot!
      @layout ||= layout_class.new(@rack_context)
      ENV['GEM_PATH'] = @layout.gem_path
      @layout.change_working_directory if @layout.respond_to?(:change_working_directory)
      begin
        require 'rubygems'
        require 'rack' # allow override via rubygems
      rescue LoadError
        require 'vendor/rack' # use jruby-rack's vendored copy
      end
      require 'time' # some of rack uses Time#rfc822 but doesn't pull this in
    end

    def default_layout_class
      WebInfLayout
    end

    def layout_class
      @layout_class ||= default_layout_class
    end

    def layout_class=(c)
      @layout_class = c
    end

    %w(app_path gem_path public_path).each do |m|
      # def app_path; @layout.app_path; end
      # def app_path=(v); @layout.app_path = v; end
      class_eval "def #{m}; @layout.#{m}; end"
      class_eval "def #{m}=(v); @layout.#{m} = v; end"
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
  end
end
