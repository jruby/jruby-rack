require 'active_support/logger_silence'

module JRuby
  module Rack
    class RailsLogger < JRuby::Rack::Logger
      include ActiveSupport::LoggerSilence

      def info(*args)
        return unless info?

        super(*args)
      end
    end
  end
end