/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;
import java.net.MalformedURLException;

import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;
import org.jruby.rack.servlet.ServletRackContext;

/**
 * A filter that does dispatch to the Ruby side and might alter the incoming
 * request URI while attempting to map to an available static resource.
 *
 * Related to serving static .html resources, supports configuration options:
 *
 * * {@link #isAddsHtmlToPathInfo()}, true by default - controls whether static
 *   resource resolution will be attempted, request methods {@code getPathInfo()}
 *   and {@code getRequestURI()} will be modified to reflect a .html path
 *
 * * {@link #isVerifiesHtmlResource()} off by default - attempts to resolve the
 *   resource using {@code context.getResource(path)} before changing the path
 *
 * @see UnmappedRackFilter
 */
public class RackFilter extends UnmappedRackFilter {

    private boolean addsHtmlToPathInfo = true;
    private boolean verifiesHtmlResource = false;

    /** Default constructor for servlet container */
    public RackFilter() {
    }

    /**
     * Dependency-injected constructor for testing
     * @param dispatcher the dispatcher
     * @param context the context
     */
    public RackFilter(RackDispatcher dispatcher, RackContext context) {
        super(dispatcher, context);
    }

    @Override
    public void init(FilterConfig config) throws ServletException {
        super.init(config);
        String value = config.getInitParameter("addsHtmlToPathInfo");
        if ( value != null ) setAddsHtmlToPathInfo(Boolean.parseBoolean(value));
        value = config.getInitParameter("verifiesHtmlResource");
        if ( value != null ) setVerifiesHtmlResource(Boolean.parseBoolean(value));
    }

    @Override
    protected void doFilterInternal(
            final RequestCapture requestCapture,
            final ResponseCapture responseCapture,
            final FilterChain chain,
            final RackEnvironment env) throws IOException, ServletException {
        ServletRequest pathChangedRequest = addHtmlToPathAndVerifyResource(requestCapture, env);
        chain.doFilter(pathChangedRequest, responseCapture);
    }

    private ServletRequest addHtmlToPathAndVerifyResource(ServletRequest request, RackEnvironment env) {
        HttpServletRequest httpRequest = (HttpServletRequest) request;

        if ( ! isAddsHtmlToPathInfo() ) return httpRequest;

        final String path = env.getPathInfo();

        final int lastDelim = path.lastIndexOf('/');
        if ( path.lastIndexOf('.') <= lastDelim ) {

            final StringBuilder htmlSuffix = new StringBuilder(10);
            if ( lastDelim == path.length() - 1 ) { // ends-with '/'
                htmlSuffix.append("index");
            }
            htmlSuffix.append(".html");

            final String htmlPath = path + htmlSuffix;
            // Welcome file list already triggered mapping to index.html, so don't modify the request any further
            if ( httpRequest.getServletPath().equals(htmlPath) ) {
                return httpRequest;
            }

            if ( isVerifiesHtmlResource() && ! resourceExists(htmlPath) ) {
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

    protected boolean resourceExists(final String path) {
        ServletRackContext servletContext = (ServletRackContext) getContext();
        try {
            return servletContext.getResource(path) != null;
        }
        catch (MalformedURLException e) {
            return false;
        }
    }

    // getters - setters :

    public boolean isAddsHtmlToPathInfo() {
        return addsHtmlToPathInfo;
    }

    public boolean isVerifiesHtmlResource() {
        return verifiesHtmlResource;
    }

    public void setAddsHtmlToPathInfo(boolean addsHtmlToPathInfo) {
        this.addsHtmlToPathInfo = addsHtmlToPathInfo;
    }

    public void setVerifiesHtmlResource(boolean verifiesHtmlResource) {
        this.verifiesHtmlResource = verifiesHtmlResource;
    }

}
