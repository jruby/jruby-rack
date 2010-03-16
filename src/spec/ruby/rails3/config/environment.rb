module Rails
  class << self
    attr_accessor :application
  end
end

require File.expand_path('../application', __FILE__)
