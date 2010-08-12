#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  module LoadPathDebugging
    def self.enabled?
      $servlet_context &&
        ($servlet_context.getInitParameter('jruby.rack.debug.load') ||
         java.lang.System.getProperty('jruby.rack.debug.load'))
    end

    def initialize(*args)
      super
      library = args.first && args.first[/-- (.*)\z/, 1]
      $servlet_context.log("LoadError while loading '#{library}', current path:\n " + $LOAD_PATH.join("\n "))
    end
  end
end

# Monkey-patch LoadError to dump out the current $LOAD_PATH upon
# initialization. For debugging the infamous "no such file to load --
# rack" and other errors.
if JRuby::Rack::LoadPathDebugging.enabled?
  class LoadError
    include JRuby::Rack::LoadPathDebugging
  end
end
