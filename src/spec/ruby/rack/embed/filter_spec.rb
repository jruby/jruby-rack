require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.embed.Filter do

  let(:rack_application) { double "rack application" }
  let(:embed_rack_context) { org.jruby.rack.embed.Context.new "test server" }
  let(:dispatcher) { org.jruby.rack.embed.Dispatcher.new embed_rack_context, rack_application }

  let(:filter) { org.jruby.rack.embed.Filter.new dispatcher, embed_rack_context }
  let(:chain) { double "filter chain" }

  let(:request) do
    javax.servlet.http.HttpServletRequest.impl {}.tap do |request|
      allow(request).to receive(:getInputStream).and_return(StubServletInputStream.new)
    end
  end
  let(:response) { javax.servlet.http.HttpServletResponse.impl {} }

  it "serves all requests using the given rack application" do
    rack_response = double "rack response"
    expect(rack_response).to receive(:respond)
    expect(rack_application).to receive(:call).and_return rack_response
    filter.doFilter(request, response, chain)
  end

end
