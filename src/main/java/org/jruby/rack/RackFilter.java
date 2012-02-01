/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.FileNotFoundException;
import java.io.IOException;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;

import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;
import org.jruby.rack.servlet.ServletRackContext;

public class RackFilter extends UnmappedRackFilter {

    private boolean addsHtmlToPath; 
    private boolean verifiesResource;

    /** Default constructor for servlet container */
    public RackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public RackFilter(RackDispatcher dispatcher, RackContext context) {
        super(dispatcher, context);
        configure();
    }

    @Override
    public void init(FilterConfig config) throws ServletException {
        super.init(config);
        configure();
    }

    private void configure() {
        addsHtmlToPath = getContext().getConfig().isFilterAddsHtml();
        verifiesResource = getContext().getConfig().isFilterVerifiesResource();
    }

    @Override
    protected boolean isDoDispatch(
            RequestCapture requestCapture, ResponseCapture responseCapture,
            FilterChain chain, RackEnvironment env,
            RackResponseEnvironment responseEnv) throws IOException, ServletException {
        try {
            chain.doFilter(addHtmlToPathAndVerifyResource(requestCapture, env), responseCapture);
        } // some AppServers (WAS 8.0) seems to be chained up too smart @see #79
        catch (FileNotFoundException e) {
            return true;
        }
        return handleError(requestCapture, responseCapture);
    }

    private ServletRequest addHtmlToPathAndVerifyResource(ServletRequest request, RackEnvironment env) {
        HttpServletRequest httpRequest = (HttpServletRequest) request;

        if ( ! addsHtmlToPath ) return httpRequest;

        final String path = env.getPathInfo();

        if ( path.lastIndexOf('.') <= path.lastIndexOf('/') ) {
            
            final StringBuilder htmlSuffix = new StringBuilder();
            if (path.endsWith("/")) {
                htmlSuffix.append("index");
            }
            htmlSuffix.append(".html");

            // Welcome file list already triggered mapping to index.html, so don't modify the request any further
            if ( httpRequest.getServletPath().equals(path + htmlSuffix) ) {
                return httpRequest;
            }

            if ( verifiesResource && ! resourceExists(path + htmlSuffix) ) {
                return httpRequest;
            }

            final String requestURI = httpRequest.getRequestURI() + htmlSuffix;
            if ( httpRequest.getPathInfo() != null ) {
                final String pathInfo = httpRequest.getPathInfo() + htmlSuffix;
                httpRequest = new HttpServletRequestWrapper(httpRequest) {

                    @Override
                    public String getPathInfo() {
                        return pathInfo;
                    }

                    @Override
                    public String getRequestURI() {
                        return requestURI;
                    }
                };
            } else {
                final String servletPath = httpRequest.getServletPath() + htmlSuffix;
                httpRequest = new HttpServletRequestWrapper(httpRequest) {

                    @Override
                    public String getServletPath() {
                        return servletPath;
                    }

                    @Override
                    public String getRequestURI() {
                        return requestURI;
                    }
                };
            }
        }
        return httpRequest;
    }

    private boolean resourceExists(final String path) {
        ServletRackContext servletContext = (ServletRackContext) getContext();
        try {
            return servletContext.getResource(path) != null;
        // FIXME: Should we really be swallowing *all* exceptions here?
        } catch (Exception e) {
            return false;
        }
    }
    
}
