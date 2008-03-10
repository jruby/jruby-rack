#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.RackFilter

describe RackFilter do
  before :each do
    @request = javax.servlet.http.HttpServletRequest.impl {}
    @response = javax.servlet.http.HttpServletResponse.impl {}
    @chain = mock "filter chain"
    @dispatcher = mock "dispatcher"
    @filter = RackFilter.new @dispatcher
  end

  it "should dispatch the filter chain and finish if the chain resulted in a successful response" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @filter.doFilter(@request, @response, @chain)
  end

  it "should finish if the chain resulted in a redirect" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendRedirect("/some/url")
    end
    @response.should_receive(:sendRedirect).ordered.with("/some/url")
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should dispatch to the rack dispatcher if the chain resulted in a client or server error" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404)
    end
    @response.should_receive(:reset).ordered
    @dispatcher.should_receive(:process).with(@request,@response).ordered
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should allow downstream entities to flush the buffer in the case of a successful response" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
      resp.flushBuffer
    end
    
    @response.should_receive(:setStatus).ordered.with(200)
    @response.should_receive(:flushBuffer).ordered
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should not allow downstream entities in the chain to flush the buffer in the case of an error" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(400)
      resp.flushBuffer
    end
    @response.should_not_receive(:flushBuffer)
    @response.should_receive(:reset).ordered
    @dispatcher.should_receive(:process).ordered.with(@request,@response)
    @filter.doFilter(@request, @response, @chain)
  end
end