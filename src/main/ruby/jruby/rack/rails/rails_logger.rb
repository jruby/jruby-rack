require 'active_support/logger_silence' unless defined?(ActiveSupport::LoggerSilence)

module JRuby::Rack
  class RailsLogger < JRuby::Rack::Logger
    include ActiveSupport::LoggerSilence if defined?(ActiveSupport::LoggerSilence)
  end
end
