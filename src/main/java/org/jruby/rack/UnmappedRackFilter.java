/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

import java.io.IOException;

/**
 * UnappedRackFilter does dispatching to Ruby but does not alter the request
 * URI or attempt to map to an available static resource.
 * @author nicksieger
 */
public class UnmappedRackFilter extends AbstractFilter {
    protected RackContext context;
    protected RackDispatcher dispatcher;

    /** Default constructor for servlet container */
    public UnmappedRackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public UnmappedRackFilter(RackDispatcher dispatcher, RackContext context) {
        this.context = context;
        this.dispatcher = dispatcher;
    }

    /** Construct a new dispatcher with the servlet context */
    public void init(FilterConfig config) throws ServletException {
          this.context = (RackContext) config.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
          this.dispatcher = new DefaultRackDispatcher(this.context);
    }

    @Override
    protected RackDispatcher getDispatcher() {
      return this.dispatcher;
    }

    @Override
    protected RackContext getContext() {
      return this.context;
    }

    @Override
    protected boolean isDoDispatch(RequestCapture req, ResponseCapture resp,
        FilterChain chain, RackEnvironment env, RackResponseEnvironment respEnv) throws IOException, ServletException {

      HttpServletRequest mappedRequest = getHttpServletRequest(req, env);
      chain.doFilter(mappedRequest, resp);

      boolean error = resp.isError();
      if (error) {
          req.reset();
          resp.reset();
          mappedRequest.setAttribute(RackEnvironment.DYNAMIC_REQS_ONLY, Boolean.TRUE);
      }
      return error;
    }

    protected HttpServletRequest getHttpServletRequest(ServletRequest request,
        RackEnvironment env) {
      return (HttpServletRequest) request;
    }

    public void destroy() {
    }
}
