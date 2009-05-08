#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Rails
  # This hook code exists to allow us to hook into the Rails boot sequence so
  # that we can set some additional defaults that are more friendly to the servlet
  # environment, but still can be overridden by the application in the Rails
  # initializer.
  #
  # Only for Rails 2.0, unfortunately. This code is mildly evil, but we're hoping
  # the Rails booter code won't change too much.
  class BootHook
    def initialize(real_boot)
      @real_boot = real_boot
    end
    def run
      result = @real_boot.run
      JRuby::Rack.booter.boot_for_servlet_environment(result)
      result
    end
    def custom_boot
    end
  end
  class Boot
    # Hook into methods added for Rails::Boot, and redefine Rails.pick_boot.
    # Only needs to be done once, so remove the method_added hook when done.
    def self.method_added(meth)
      class << ::Rails
        alias_method :original_pick_boot, :pick_boot
        def pick_boot
          BootHook.new(original_pick_boot)
        end
      end
      class << self; remove_method :method_added; end
    end
  end
end
