#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# Monkey-patch LoadError's message to include the current $LOAD_PATH.
# For debugging the infamous "no such file to load -- rack" and other
# errors.
class LoadError
  def initialize(*args)
    super
    @path = $LOAD_PATH.dup
  end

  def message
    $servlet_context.log("Current path:\n" + @path.join("\n")) if $servlet_context
    super
  end
end
