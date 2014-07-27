
# This is a fake Rails config/boot file to be used during testing.

RAILS_ROOT = "#{ENV['RAILS_ROOT']}"

# Simulate the Rails 2.0 boot process here, to test our boot hook
module Rails
  class << self
    def boot!
      unless booted?
        pick_boot.run
      end
    end

    def booted?
      defined? Rails::Initializer
    end

    def pick_boot
      Boot.new
    end
  end

  class Boot
    def run
      require 'initializer'
      # @see #rails/stub/initializer.rb
      Rails::Initializer.run(:set_load_path)
    end
  end
end

Rails.boot!
