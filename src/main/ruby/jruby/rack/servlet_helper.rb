#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    class ServletHelper
      def initialize(rack_context = nil)
        @rack_context = rack_context || $servlet_context
        @layout = layout_class.new(@rack_context)
        ENV['GEM_PATH'] = @layout.gem_path
        ServletHelper.instance = self
      end

      def self.layout_class
        @layout_class ||= WebInfLayout
      end

      def layout_class
        self.class.layout_class
      end

      def self.layout_class=(c)
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

      def change_to_root_directory
        Dir.chdir(app_path) if File.directory?(app_path)
      end

      def silence_warnings(&block)
        JRuby::Rack.silence_warnings(&block)
      end

      def self.instance
        @instance ||= self.new
      end

      def self.instance=(inst)
        @instance = inst
      end
    end
  end
end
