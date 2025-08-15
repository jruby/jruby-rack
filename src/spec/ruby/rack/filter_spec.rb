#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.RackFilter do

  let(:dispatcher) { double "dispatcher" }
  let(:filter) { org.jruby.rack.RackFilter.new dispatcher, @rack_context }
  let(:chain) { double "filter chain" }

  def stub_request(path_info)
    @request = Java::JakartaServletHttp::HttpServletRequest.impl {}
    allow(@request).to receive(:setAttribute)
    if block_given?
      yield @request, path_info
    else
      allow(@request).to receive(:getPathInfo).and_return nil
      allow(@request).to receive(:getServletPath).and_return "/some/uri#{path_info}"
    end
    allow(@request).to receive(:getRequestURI).and_return "/some/uri#{path_info}"
  end

  before :each do
    stub_request("/index")
    @response = Java::JakartaServletHttp::HttpServletResponse.impl {}
    allow(@rack_context).to receive(:getResource).and_return nil
    allow(@rack_config).to receive(:getProperty) do |key, default|
      (key || raise("missing key")) && default
    end
    allow(@rack_config).to receive(:getBooleanProperty) do |key, default|
      (key || raise("missing key")) && default
    end
    filter.setAddsHtmlToPathInfo(true)
  end

  it "should dispatch the filter chain and finish if the chain resulted in a successful response" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.setStatus(200)
    end
    expect(@response).to receive(:setStatus).ordered.with(200)
    filter.doFilter(@request, @response, chain)
  end

  it "should finish if the chain resulted in a redirect" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendRedirect("/some/url")
    end
    expect(@response).to receive(:sendRedirect).ordered.with("/some/url")
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 404" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(404)
    end
    expect(@response).to receive(:reset).ordered
    expect(@request).to receive(:setAttribute).ordered.with(org.jruby.rack.RackEnvironment::DYNAMIC_REQS_ONLY, true)
    expect(dispatcher).to receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 403" do
    # sending a PUT up the chain results in a 403 on Tomcat
    # @see https://github.com/jruby/jruby-rack/issues/105
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(403)
    end
    expect(@response).to receive(:reset).ordered
    expect(dispatcher).to receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 405" do
    # PUT/DELETE up the chain end up as HTTP 405 on Jetty
    # @see https://github.com/jruby/jruby-rack/issues/109
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(405)
    end
    expect(@response).to receive(:reset).ordered
    expect(dispatcher).to receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 501" do
    # non standard verbs like PATCH produce HTTP 501
    # see also http://httpstatus.es/501 and http://tools.ietf.org/html/rfc5789
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(501)
    end
    expect(@response).to receive(:reset)
    expect(dispatcher).to receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher out of configured non handled statuses" do
    filter = Class.new(org.jruby.rack.RackFilter) do
      def wrapResponse(response)
        capture = super
        capture.setNotHandledStatuses [442]
        capture
      end
    end.new(dispatcher, @rack_context)

    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(442)
    end
    expect(@response).to receive(:reset).ordered
    expect(dispatcher).to receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "allows downstream entities to flush the buffer in the case of a successful response" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.setStatus(200)
      resp.flushBuffer
    end
    expect(@response).to receive(:setStatus).ordered.with(200)
    expect(@response).to receive(:flushBuffer).ordered
    expect(dispatcher).not_to receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "does not allow downstream entities in the chain to flush the buffer in the case of an 404" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(404)
      resp.flushBuffer
    end
    expect(@response).not_to receive(:flushBuffer)
    expect(@response).to receive(:reset)
    expect(dispatcher).to receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "only resets the buffer for a 404 if configured so" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(404)
      resp.flushBuffer
    end
    expect(@response).not_to receive(:flushBuffer)
    expect(@response).to receive(:resetBuffer)
    expect(@response).not_to receive(:reset)
    expect(dispatcher).to receive(:process)
    filter.setResetUnhandledResponseBuffer(true)
    filter.doFilter(@request, @response, chain)
  end

  it "allows an error response from the filter chain (and flushes the buffer)" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(401)
      resp.flushBuffer
    end
    expect(@response).to receive(:sendError).with(401).ordered
    expect(@response).to receive(:flushBuffer).ordered
    expect(@response).not_to receive(:reset)
    expect(dispatcher).not_to receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "processes and resets in case a given chain error is not considered handled" do
    filter = Class.new(org.jruby.rack.RackFilter) do
      def wrapResponse(response)
        Class.new(org.jruby.rack.servlet.ResponseCapture) do
          def isHandled(arg)
            ; getStatus < 400;
          end
        end.new(response)
      end
    end.new(dispatcher, @rack_context)

    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(401)
      resp.flushBuffer
    end
    expect(@response).not_to receive(:flushBuffer)
    expect(@response).to receive(:reset)
    expect(dispatcher).to receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "should only add to path info if it already was non-null" do
    stub_request("/index") do |request, path_info|
      allow(request).to receive(:getPathInfo).and_return path_info
      allow(request).to receive(:getServletPath).and_return "/some/uri"
    end
    expect(chain).to receive(:doFilter).ordered do |req, resp|
      expect(req.getPathInfo).to eq "/index.html"
      expect(req.getServletPath).to eq "/some/uri"
      expect(req.getRequestURI).to eq "/some/uri/index.html"
      resp.setStatus(200)
    end
    expect(@response).to receive(:setStatus).ordered.with(200)
    filter.doFilter(@request, @response, chain)
  end

  it "should set status to 404 when dispatcher's status is not found" do
    expect(chain).to receive(:doFilter).ordered do |_, resp|
      resp.sendError(404) # 404 status is irrelevant here !
    end
    expect(@response).to receive(:reset).ordered
    expect(@request).to receive(:setAttribute).ordered.with(org.jruby.rack.RackEnvironment::DYNAMIC_REQS_ONLY, true)
    expect(dispatcher).to receive(:process).ordered do |_, resp|
      resp.setStatus(404)
    end
    expect(@response).to receive(:setStatus).ordered.with(404)
    filter.doFilter(@request, @response, chain)
  end

  context "adds .html to path info" do

    before do
      filter.setAddsHtmlToPathInfo(true)
    end

    it "should dispatch /some/uri/index.html unchanged" do
      stub_request("/index.html")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getRequestURI).to eq "/some/uri/index.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should convert / to /index.html" do
      stub_request("/")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getServletPath).to eq "/some/uri/index.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch the request unwrapped if servlet path already contains the welcome filename" do
      stub_request("/") do |request, path_info|
        allow(request).to receive(:getPathInfo).and_return nil
        allow(request).to receive(:getServletPath).and_return "/some/uri/index.html"
      end
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getPathInfo).to eq nil
        expect(req.getServletPath).to eq "/some/uri/index.html"
        expect(req.getRequestURI).to eq "/some/uri/"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should add .html to the path" do
      stub_request("")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getServletPath).to eq "/some/uri.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should process dispatching when chain throws a FileNotFoundException (WAS 8.0 behavior)" do
      stub_request("/foo")
      expect(chain).to receive(:doFilter).ordered do
        raise java.io.FileNotFoundException.new("/foo.html")
      end
      expect(dispatcher).to receive(:process)
      filter.doFilter(@request, @response, chain)
    end

  end

  context "down not add .html to path info" do

    before do
      filter.setAddsHtmlToPathInfo(false)
    end

    it "dispatches /some/uri/index unchanged" do
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getServletPath).to eq "/some/uri/index"
        expect(req.getRequestURI).to eq "/some/uri/index"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end
  end

  context "verifies .html resources" do

    before do
      filter.setAddsHtmlToPathInfo(true)
      filter.setVerifiesHtmlResource(true)
    end

    it "dispatches /some/uri/index unchanged if the resource does not exist" do
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getRequestURI).to eq "/some/uri/index"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch /some/uri/index to the filter chain as /some/uri/index.html if the resource exists" do
      expect(@rack_context).to receive(:getResource).with("/some/uri/index.html").and_return java.net.URL.new("file://some/uri/index.html")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getRequestURI).to eq "/some/uri/index.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch /some/uri/ to /some/uri/index.html if the resource exists" do
      expect(@rack_context).to receive(:getResource).with("/some/uri/index.html").and_return java.net.URL.new("file://some/uri/index.html")
      stub_request("/")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getRequestURI).to eq "/some/uri/index.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch to /some/uri.html if the resource exists and there is no path info" do
      expect(@rack_context).to receive(:getResource).with("/some/uri.html").and_return java.net.URL.new("file://some/uri.html")
      stub_request("")
      expect(chain).to receive(:doFilter).ordered do |req, resp|
        expect(req.getServletPath).to eq "/some/uri.html"
        resp.setStatus(200)
      end
      expect(@response).to receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end
  end

  it "configures not handled statuses on init" do
    servlet_context = Java::JakartaServlet::ServletContext.impl do |name, *args|
      case name.to_sym
      when :getAttribute
        if args[0] == "rack.context"
          @rack_context
        end
      else
        nil
      end
    end
    config = Java::JakartaServlet::FilterConfig.impl do |name, *args|
      case name.to_sym
      when :getServletContext then servlet_context
      when :getInitParameter
        if args[0] == 'responseNotHandledStatuses'
          ' 403, 404,501, , 504 ,'
        end
      else
        nil
      end
    end
    filter.init(config)
    response_capture = filter.wrapResponse(@response)
    response_capture.setStatus(403)
    expect(response_capture.isHandled).to be false
    response_capture.setStatus(404)
    expect(response_capture.isHandled).to be false
    response_capture.setStatus(501)
    expect(response_capture.isHandled).to be false
    response_capture.setStatus(504)
    expect(response_capture.isHandled).to be false
    response_capture.setStatus(505)
    expect(response_capture.isHandled).to be true
  end

  it "should destroy dispatcher on destroy" do
    expect(dispatcher).to receive(:destroy)
    filter.destroy
  end

  it "should have default constructor (for servlet container)" do
    expect { org.jruby.rack.RackFilter.new }.not_to raise_error
  end

end
