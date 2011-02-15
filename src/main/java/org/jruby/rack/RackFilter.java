/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;
import java.io.IOException;

/**
 *
 * @author nicksieger
 */
public class RackFilter implements Filter {
    private RackContext context;
    private RackDispatcher dispatcher;
    private boolean filterAddsHtml, filterVerifiesResource;

    /** Default constructor for servlet container */
    public RackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public RackFilter(RackDispatcher dispatcher, RackContext context) {
        this.context = context;
        this.dispatcher = dispatcher;
        configure();
    }

    /** Construct a new dispatcher with the servlet context */
    public void init(FilterConfig config) throws ServletException {
        this.context = (RackContext) config.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
        this.dispatcher = new DefaultRackDispatcher(this.context);
        configure();
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        RackEnvironment env = new ServletRackEnvironment((HttpServletRequest) request, context);
        RackResponseEnvironment responseEnv = new ServletRackResponseEnvironment((HttpServletResponse) response);
        HttpServletRequest    httpRequest  = maybeAppendHtmlToPath(request, env);
        HttpServletResponse   httpResponse = (HttpServletResponse) response;
        ResponseStatusCapture capture      = new ResponseStatusCapture(httpResponse);
        chain.doFilter(httpRequest, capture);
        if (capture.isError()) {
            httpResponse.reset();
            request.setAttribute(RackEnvironment.DYNAMIC_REQS_ONLY, Boolean.TRUE);
            dispatcher.process(env, responseEnv);
        }
    }

    public void destroy() {
    }

    private void configure() {
        this.filterAddsHtml = context.getConfig().isFilterAddsHtml();
        this.filterVerifiesResource = context.getConfig().isFilterVerifiesResource();
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

    private HttpServletRequest maybeAppendHtmlToPath(ServletRequest request, RackEnvironment env) {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        if (!filterAddsHtml) {
            return httpRequest;
        }

        String path = env.getPathInfo();

        if (path.lastIndexOf('.') <= path.lastIndexOf('/')) {
            if (path.endsWith("/")) {
                path += "index";
            }
            path += ".html";

            if (filterVerifiesResource && !resourceExists(path)) {
                return httpRequest;
            }

            final String uri = path;
            httpRequest = new HttpServletRequestWrapper(httpRequest) {
                @Override
                public String getPathInfo() {
                    return uri;
                }
                @Override
                public String getServletPath() {
                    return "";
                }
                @Override
                public String getRequestURI() {
                    return uri;
                }
            };
        }
        return httpRequest;
    }

    private boolean resourceExists(String path) {
        try {
            return context.getResource(path) != null;
        } catch (Exception e) {
            return false;
        }
    }
}
