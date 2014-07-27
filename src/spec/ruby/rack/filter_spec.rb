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
    @request = javax.servlet.http.HttpServletRequest.impl {}
    @request.stub(:setAttribute)
    if block_given?
      yield @request, path_info
    else
      @request.stub(:getPathInfo).and_return nil
      @request.stub(:getServletPath).and_return "/some/uri#{path_info}"
    end
    @request.stub(:getRequestURI).and_return "/some/uri#{path_info}"
  end

  before :each do
    stub_request("/index")
    @response = javax.servlet.http.HttpServletResponse.impl {}
    @rack_context.stub(:getResource).and_return nil
    @rack_config.stub(:getProperty) do |key, default|
      ( key || raise("missing key") ) && default
    end
    @rack_config.stub(:getBooleanProperty) do |key, default|
      ( key || raise("missing key") ) && default
    end
    filter.setAddsHtmlToPathInfo(true)
  end

  it "should dispatch the filter chain and finish if the chain resulted in a successful response" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    filter.doFilter(@request, @response, chain)
  end

  it "should finish if the chain resulted in a redirect" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendRedirect("/some/url")
    end
    @response.should_receive(:sendRedirect).ordered.with("/some/url")
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 404" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404)
    end
    @response.should_receive(:reset).ordered
    @request.should_receive(:setAttribute).ordered.with(org.jruby.rack.RackEnvironment::DYNAMIC_REQS_ONLY, true)
    dispatcher.should_receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 403" do
    # sending a PUT up the chain results in a 403 on Tomcat
    # @see https://github.com/jruby/jruby-rack/issues/105
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(403)
    end
    @response.should_receive(:reset).ordered
    dispatcher.should_receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher if the chain resulted in a 405" do
    # PUT/DELETE up the chain end up as HTTP 405 on Jetty
    # @see https://github.com/jruby/jruby-rack/issues/109
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(405)
    end
    @response.should_receive(:reset).ordered
    dispatcher.should_receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "dispatches to the rack dispatcher out of configured non handled statuses" do
    filter = Class.new(org.jruby.rack.RackFilter) do
      def wrapResponse(response)
        capture = super
        capture.setNotHandledStatuses [ 442 ]
        capture
      end
    end.new(dispatcher, @rack_context)

    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(442)
    end
    @response.should_receive(:reset).ordered
    dispatcher.should_receive(:process).ordered
    filter.doFilter(@request, @response, chain)
  end

  it "allows downstream entities to flush the buffer in the case of a successful response" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
      resp.flushBuffer
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @response.should_receive(:flushBuffer).ordered
    dispatcher.should_not_receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "does not allow downstream entities in the chain to flush the buffer in the case of an 404" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404)
      resp.flushBuffer
    end
    @response.should_not_receive(:flushBuffer)
    @response.should_receive(:reset)
    dispatcher.should_receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "only resets the buffer for a 404 if configured so" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404)
      resp.flushBuffer
    end
    @response.should_not_receive(:flushBuffer)
    @response.should_receive(:resetBuffer)
    @response.should_not_receive(:reset)
    dispatcher.should_receive(:process)
    filter.setResetUnhandledResponseBuffer(true)
    filter.doFilter(@request, @response, chain)
  end

  it "allows an error response from the filter chain (and flushes the buffer)" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(401)
      resp.flushBuffer
    end
    @response.should_receive(:sendError).with(401).ordered
    @response.should_receive(:flushBuffer).ordered
    @response.should_not_receive(:reset)
    dispatcher.should_not_receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "processes and resets in case a given chain error is not considered handled" do
    filter = Class.new(org.jruby.rack.RackFilter) do
      def wrapResponse(response)
        Class.new(org.jruby.rack.servlet.ResponseCapture) do
          def isHandled(arg); getStatus < 400; end
        end.new(response)
      end
    end.new(dispatcher, @rack_context)

    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(401)
      resp.flushBuffer
    end
    @response.should_not_receive(:flushBuffer)
    @response.should_receive(:reset)
    dispatcher.should_receive(:process)
    filter.doFilter(@request, @response, chain)
  end

  it "should only add to path info if it already was non-null" do
    stub_request("/index") do |request,path_info|
      request.stub(:getPathInfo).and_return path_info
      request.stub(:getServletPath).and_return "/some/uri"
    end
    chain.should_receive(:doFilter).ordered.and_return do |req,resp|
      req.getPathInfo.should == "/index.html"
      req.getServletPath.should == "/some/uri"
      req.getRequestURI.should == "/some/uri/index.html"
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    filter.doFilter(@request, @response, chain)
  end

  it "should set status to 404 when dispatcher's status is not found" do
    chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404) # 404 status is irrelevant here !
    end
    @response.should_receive(:reset).ordered
    @request.should_receive(:setAttribute).ordered.with(org.jruby.rack.RackEnvironment::DYNAMIC_REQS_ONLY, true)
    dispatcher.should_receive(:process).ordered.and_return do |_, resp|
      resp.setStatus(404)
    end
    @response.should_receive(:setStatus).ordered.with(404)
    filter.doFilter(@request, @response, chain)
  end

  context "adds .html to path info" do

    before do
      filter.setAddsHtmlToPathInfo(true)
    end

    it "should dispatch /some/uri/index.html unchanged" do
      stub_request("/index.html")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getRequestURI.should == "/some/uri/index.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should convert / to /index.html" do
      stub_request("/")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getServletPath.should == "/some/uri/index.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch the request unwrapped if servlet path already contains the welcome filename" do
      stub_request("/") do |request, path_info|
        request.stub(:getPathInfo).and_return nil
        request.stub(:getServletPath).and_return "/some/uri/index.html"
      end
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getPathInfo.should == nil
        req.getServletPath.should == "/some/uri/index.html"
        req.getRequestURI.should == "/some/uri/"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should add .html to the path" do
      stub_request("")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getServletPath.should == "/some/uri.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should process dispatching when chain throws a FileNotFoundException (WAS 8.0 behavior)" do
      stub_request("/foo")
      chain.should_receive(:doFilter).ordered.and_return do
        raise java.io.FileNotFoundException.new("/foo.html")
      end
      dispatcher.should_receive(:process)
      filter.doFilter(@request, @response, chain)
    end

  end

  context "down not add .html to path info" do

    before do
      filter.setAddsHtmlToPathInfo(false)
    end

    it "dispatches /some/uri/index unchanged" do
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getServletPath.should == "/some/uri/index"
        req.getRequestURI.should == "/some/uri/index"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end
  end

  context "verifies .html resources" do

    before do
      filter.setAddsHtmlToPathInfo(true)
      filter.setVerifiesHtmlResource(true)
    end

    it "dispatches /some/uri/index unchanged if the resource does not exist" do
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getRequestURI.should == "/some/uri/index"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch /some/uri/index to the filter chain as /some/uri/index.html if the resource exists" do
      @rack_context.should_receive(:getResource).with("/some/uri/index.html").and_return java.net.URL.new("file://some/uri/index.html")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getRequestURI.should == "/some/uri/index.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch /some/uri/ to /some/uri/index.html if the resource exists" do
      @rack_context.should_receive(:getResource).with("/some/uri/index.html").and_return java.net.URL.new("file://some/uri/index.html")
      stub_request("/")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getRequestURI.should == "/some/uri/index.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end

    it "should dispatch to /some/uri.html if the resource exists and there is no path info" do
      @rack_context.should_receive(:getResource).with("/some/uri.html").and_return java.net.URL.new("file://some/uri.html")
      stub_request("")
      chain.should_receive(:doFilter).ordered.and_return do |req,resp|
        req.getServletPath.should == "/some/uri.html"
        resp.setStatus(200)
      end
      @response.should_receive(:setStatus).ordered.with(200)
      filter.doFilter(@request, @response, chain)
    end
  end

  it "configures not handled statuses on init" do
    servlet_context = javax.servlet.ServletContext.impl do |name, *args|
      case name.to_sym
      when :getAttribute
        if args[0] == "rack.context"
          @rack_context
        end
      else
        nil
      end
    end
    config = javax.servlet.FilterConfig.impl do |name, *args|
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
    response_capture.isHandled.should be false
    response_capture.setStatus(404)
    response_capture.isHandled.should be false
    response_capture.setStatus(501)
    response_capture.isHandled.should be false
    response_capture.setStatus(504)
    response_capture.isHandled.should be false
    response_capture.setStatus(505)
    response_capture.isHandled.should be true
  end

  it "should destroy dispatcher on destroy" do
    dispatcher.should_receive(:destroy)
    filter.destroy
  end

  it "should have default constructor (for servlet container)" do
    lambda { org.jruby.rack.RackFilter.new }.should_not raise_error
  end

end
