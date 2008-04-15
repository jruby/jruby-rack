#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.RackServlet

describe RackServlet, "service" do
  it "should delegate to process" do
    request = javax.servlet.http.HttpServletRequest.impl {}
    response = javax.servlet.http.HttpServletResponse.impl {}
    dispatcher = mock "dispatcher"
    dispatcher.should_receive(:process).with(request, response)
    @servlet = RackServlet.new dispatcher
    @servlet.service request, response
  end
end
