require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe org.jruby.rack.servlet.ResponseCapture do

  let(:servlet_response) { MockHttpServletResponse.new }
  let(:response_capture) do
    org.jruby.rack.servlet.ResponseCapture.new(servlet_response)
  end

  it "reports if output (stream) has been accessed" do
    expect( response_capture.isOutputAccessed ).to be false

    response_capture.getOutputStream
    expect( response_capture.isOutputAccessed ).to be true
  end

  it "reports if output (writer) has been accessed" do
    response_capture.getWriter
    expect( response_capture.isOutputAccessed ).to be true
  end

  it "is not considered handled by default or when 404 set" do
    expect( response_capture.isHandled ).to be false

    response_capture.setStatus(404)
    expect( response_capture.isHandled ).to be false
  end

  it "is considered handled when 200 status is set" do
    response_capture.setStatus(200)
    expect( response_capture.isHandled ).to be true
  end

end