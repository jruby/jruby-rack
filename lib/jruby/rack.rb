#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require 'rack'
require 'time' # some of rack uses Time#rfc822 but doesn't pull this in
require 'jruby/rack/servlet_helper'
