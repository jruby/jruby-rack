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

  before :each do
    stub_request("/index")
    @response = javax.servlet.http.HttpServletResponse.impl {}
  end

  def stub_request(path_info)
    @request = javax.servlet.http.HttpServletRequest.impl {}
    @request.stub!(:setAttribute)
    if block_given?
      yield @request, path_info
    else
      @request.stub!(:getPathInfo).and_return nil
      @request.stub!(:getServletPath).and_return "/some/uri#{path_info}"
    end
    @request.stub!(:getRequestURI).and_return "/some/uri#{path_info}"
  end

  it "serves all requests using the given rack application" do
    rack_response = mock "rack response"
    rack_response.should_receive(:respond)
    rack_application.should_receive(:call).and_return rack_response
    filter.doFilter(@request, @response, chain)
  end

end
