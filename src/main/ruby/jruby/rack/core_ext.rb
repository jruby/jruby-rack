#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# Monkey-patch LoadError's message to include the current $LOAD_PATH.
# For debugging the infamous "no such file to load -- rack" and other
# errors.
if $servlet_context &&
    ($servlet_context.getInitParameter('jruby.rack.debug.load') ||
     java.lang.System.getProperty('jruby.rack.debug.load'))
  class LoadError
    def initialize(*args)
      super
      @path = $LOAD_PATH.dup
    end

    def message
      $servlet_context.log("Current path:\n" + @path.join("\n"))
      super
    end
  end
end
