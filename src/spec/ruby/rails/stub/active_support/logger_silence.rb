# frozen_string_literal: true

# require "active_support/concern"
# require "active_support/core_ext/module/attribute_accessors"
require "active_support/logger_thread_safe_level"

module ActiveSupport
  module LoggerSilence
    # extend ActiveSupport::Concern

    def self.included(base)
      base.class_eval do
        # cattr_accessor :silencer, default: true
        @@silencer = true
        module_eval do
          def self.silencer; @@silencer end
          def silencer; @@silencer end
        end

        include ActiveSupport::LoggerThreadSafeLevel
      end
    end

    # Silences the logger for the duration of the block.
    def silence(severity = Logger::ERROR)
      silencer ? log_at(severity) { yield(self) } : yield(self)
    end
  end
end