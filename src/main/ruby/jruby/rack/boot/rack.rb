#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby::Rack
  Bootstrap = ServletHelper unless defined?(Bootstrap)
  Bootstrap.instance.change_working_directory
end
