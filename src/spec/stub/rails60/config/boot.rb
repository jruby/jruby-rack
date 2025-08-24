ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# workaround for https://github.com/ruby-concurrency/concurrent-ruby/issues/1077 since https://github.com/rails/rails/pull/54264 wont be backported earlier than 7.1.
require "logger"
