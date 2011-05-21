/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;
import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public class RackFilter extends AbstractFilter {
    protected RackContext context;
    protected RackDispatcher dispatcher;

    /** Default constructor for servlet container */
    public RackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public RackFilter(RackDispatcher dispatcher, RackContext context) {
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
    protected boolean doDispatch(HttpServletRequest req, HttpServletResponse resp,
        FilterChain chain, RackEnvironment env, RackResponseEnvironment respEnv) throws IOException, ServletException {

      HttpServletRequest httpRequest = getHttpServletRequest(req, env);
      ResponseStatusCapture capture = new ResponseStatusCapture(resp);
      chain.doFilter(httpRequest, capture);

      if (capture.isError()) {
        resp.reset();
      }

      return capture.isError();
    }

    protected HttpServletRequest getHttpServletRequest(ServletRequest request,
        RackEnvironment env) {
      return (HttpServletRequest) request;
    }

    public void destroy() {
    }


    private static class ResponseStatusCapture extends HttpServletResponseWrapper {
        private int status = 200;

        public ResponseStatusCapture(HttpServletResponse response) {
            super(response);
        }

        @Override public void sendError(int status, String message) throws IOException {
            this.status = status;
        }

        @Override public void sendError(int status) throws IOException {
            this.status = status;
        }

        @Override public void sendRedirect(String path) throws IOException {
            this.status = 302;
            super.sendRedirect(path);
        }

        @Override public void setStatus(int status) {
            this.status = status;
            if (!isError()) {
                super.setStatus(status);
            }
        }

        @Override public void setStatus(int status, String message) {
            this.status = status;
            if (!isError()) {
                super.setStatus(status, message);
            }
        }

        @Override public void flushBuffer() throws IOException {
            if (!isError()) {
                super.flushBuffer();
            }
        }

        private boolean isError() {
            return status >= 400;
        }
    }

}
