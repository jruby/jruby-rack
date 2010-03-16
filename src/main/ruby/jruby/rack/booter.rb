#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  class Booter
    def initialize(rack_context = nil)
      @rack_context = rack_context || $servlet_context
      @rack_env = @rack_context.getInitParameter('rack.env') || 'production'
      JRuby::Rack.booter = self
    end

    def boot!
      ENV['RACK_ENV'] = @rack_env
      ENV['GEM_PATH'] = layout.gem_path
      layout.change_working_directory if layout.respond_to?(:change_working_directory)
      require 'vendor/rack'
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
  end
end
