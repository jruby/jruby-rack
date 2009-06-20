/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpServletResponseWrapper;

import org.jruby.rack.servlet.DefaultServletDispatcher;
import org.jruby.rack.servlet.ServletDispatcher;
import org.jruby.rack.servlet.ServletRackContext;

/**
 *
 * @author nicksieger
 */
public class RackFilter implements Filter {
    private ServletDispatcher dispatcher;

    /** Default constructor for servlet container */
    public RackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public RackFilter(ServletDispatcher disp) {
        dispatcher = disp;
    }

    /** Construct a new dispatcher with the servlet context */
    public void init(FilterConfig config) throws ServletException {
        dispatcher = new DefaultServletDispatcher(new ServletRackContext(config.getServletContext()));
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest    httpRequest  = maybeAppendHtmlToPath(request);
        HttpServletResponse   httpResponse = (HttpServletResponse) response;
        ResponseStatusCapture capture      = new ResponseStatusCapture(httpResponse);
        chain.doFilter(httpRequest, capture);
        if (capture.isError()) {
            httpResponse.reset();
            request.setAttribute(RackEnvironment.DYNAMIC_REQS_ONLY, Boolean.TRUE);
            dispatcher.process((HttpServletRequest) request, httpResponse);
        }
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

    private HttpServletRequest maybeAppendHtmlToPath(ServletRequest request) {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        String servletPath             = httpRequest.getServletPath();
        String pathInfo                = httpRequest.getPathInfo();
        String uri                     = servletPath;

        if (pathInfo != null) {
            uri += pathInfo;
        }
        if (uri.lastIndexOf('.') <= uri.lastIndexOf('/')) {

            final String maybeIndex;
            if (uri.endsWith("/")) {
                maybeIndex = "index";
            } else {
                maybeIndex = "";
            }

            if (pathInfo != null) {
                httpRequest = new HttpServletRequestWrapper(httpRequest) {
                    @Override
                    public String getPathInfo() {
                        return super.getPathInfo() + maybeIndex + ".html";
                    }
                };
            } else {
                httpRequest = new HttpServletRequestWrapper(httpRequest) {
                    @Override
                    public String getServletPath() {
                        return super.getServletPath() + maybeIndex + ".html";
                    }
                };
            }
        }
        return httpRequest;
    }
}