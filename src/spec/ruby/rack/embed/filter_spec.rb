#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.RackResponse
import org.jruby.rack.embed.Dispatcher
import org.jruby.rack.embed.Filter
import org.jruby.rack.embed.Context

describe Filter do
  let(:embed_rack_context) { Context.new "test server" }
  let(:rack_application) { mock "rack application" }
  let(:dispatcher) { Dispatcher.new embed_rack_context, rack_application  }
  let(:filter) { Filter.new dispatcher, embed_rack_context }
  let(:chain) { mock "filter chain" }
  let(:request) { javax.servlet.http.HttpServletRequest.impl {}.tap {|r| r.stub!(:getInputStream).and_return(StubServletInputStream.new) } }
  let(:response) { javax.servlet.http.HttpServletResponse.impl {} }

  it "serves all requests using the given rack application" do
    rack_response = mock "rack response"
    rack_response.should_receive(:respond)
    rack_application.should_receive(:call).and_return rack_response
    filter.doFilter(request, response, chain)
  end
end
