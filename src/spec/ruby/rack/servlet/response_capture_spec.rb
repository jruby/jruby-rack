require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe org.jruby.rack.servlet.ResponseCapture do

  let(:servlet_response) { MockHttpServletResponse.new }
  let(:response_capture) do
    response = org.jruby.rack.servlet.ResponseCapture.new(servlet_response)
    response.handled_by_default = true
    response
  end

  let(:servlet_request) { MockHttpServletRequest.new(@servlet_context) }

  it "reports if output (stream) has been accessed" do
    expect( response_capture.isOutputAccessed ).to be false

    response_capture.getOutputStream
    expect( response_capture.isOutputAccessed ).to be true
  end

  it "reports if output (writer) has been accessed" do
    response_capture.getWriter
    expect( response_capture.isOutputAccessed ).to be true
  end

  it "is considered handled by default" do
    # NOTE: weird but this is what some containers need to e.g. serve
    # static content with RackFilter correctly (e.g. Jetty)
    expect( response_capture.isHandled ).to be true
  end

  it "is not considered handled by default or when 404 set" do
    #expect( response_capture.isHandled ).to be false

    response_capture.setStatus(404)
    expect( response_capture.isHandled ).to be false

    servlet_request.method = 'OPTIONS'

    expect( response_capture.isHandled(servlet_request) ).to be false
  end

  it "is considered handled when 200 status is set" do
    response_capture.setStatus(200)
    expect( response_capture.isHandled ).to be true
  end

  it "once considered handled stays handled" do
    response_capture.setStatus(200)
    expect( response_capture.isHandled ).to be true
    # NOTE: quite important since container might have accessed and written to
    # the real output-stream already ... status change should not happen though
    response_capture.setStatus(404)
    expect( response_capture.isHandled ).to be true
  end

  it "is not considered handled when only Allow header is added with OPTIONS" do
    servlet_request.method = 'OPTIONS'

    #expect( response_capture.isHandled(servlet_request) ).to be false

    # NOTE: this is what TC's DefaultServlet does on doOptions() :
    response_capture.addHeader "Allow", "GET, POST, OPTIONS"

    expect( response_capture.isHandled(servlet_request) ).to be false
  end

  it "is not considered handled when only Allow or Date header is added with OPTIONS" do
    servlet_request.method = 'OPTIONS'

    # NOTE: Jetty sets both Date and Allow in DefaultServlet#doOptions
    response_capture.addHeader "Allow", "GET, POST, OPTIONS"
    response_capture.addHeader "Date", Time.now.httpdate

    expect( response_capture.isHandled(servlet_request) ).to be false
  end

  it "is considered handled when more than Allow header is added with OPTIONS" do
    pending "need Servlet API 3.0" unless servlet_30?

    servlet_request.method = 'OPTIONS'

    response_capture.setIntHeader "Answer", 42
    response_capture.setHeader "Allow", "GET, POST"

    expect( response_capture.isHandled(servlet_request) ).to be true
  end

  it "is considered handled when header is added" do
    pending "need Servlet API 3.0" unless servlet_30?

    servlet_request.method = 'OPTIONS'

    response_capture.addHeader "Hello", "World"

    expect( response_capture.isHandled(servlet_request) ).to be true
    expect( response_capture.getStatus ).to eql 200
  end

  it "is considered handled when a header is set" do
    response_capture.setIntHeader "Timeout", 42

    expect( response_capture.isHandled ).to be true
    expect( response_capture.getStatus ).to eql 200
  end

  private

  def servlet_30?
    Java::JavaClass.for_name('javax.servlet.AsyncContext') rescue nil
  end

end
