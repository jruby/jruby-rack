#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

tried_gem = false
begin
  require 'rack'
rescue LoadError
  unless tried_gem
    tried_gem = true
    require 'rubygems'
    gem 'rack'
    retry
  end
end

require 'rack/handler/servlet'
