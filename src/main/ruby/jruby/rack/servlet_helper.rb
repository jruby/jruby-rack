#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

def toplevel_binding; binding; end

module JRuby
  module Rack
    class ServletHelper
      def initialize(rack_context = nil)
        @rack_context = rack_context || $servlet_context
        bootstrap_script = @rack_context.getInitParameter('rack.bootstrap.script')
        eval(bootstrap_script, toplevel_binding) if bootstrap_script
        @layout ||= layout_class.new(@rack_context)
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

      def change_working_directory
        @layout.change_working_directory if @layout.respond_to?(:change_working_directory)
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
