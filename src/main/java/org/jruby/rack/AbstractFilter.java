/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import java.io.IOException;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;
import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

/**
 * A base (servlet) filter implementation.
 *
 * @see UnmappedRackFilter
 * @see RackFilter
 */
public abstract class AbstractFilter implements Filter {

    /**
     * @return the rack context for the application
     */
    protected abstract RackContext getContext();

    /**
     * @return the rack dispatcher for the application
     */
    protected abstract RackDispatcher getDispatcher();

    /**
     * @see Filter#doFilter(ServletRequest, ServletResponse, FilterChain)
     * @param request the request
     * @param response the response
     * @param chain the FilterChain
     * @throws IOException if there's an IO exception
     * @throws ServletException if there's a servlet exception
     */
    public final void doFilter(
            ServletRequest request, ServletResponse response,
            FilterChain chain) throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        RequestCapture requestCapture = wrapRequest(httpRequest);
        ResponseCapture responseCapture = wrapResponse(httpResponse);

        RackEnvironment env = new ServletRackEnvironment(httpRequest, httpResponse, getContext());
        // NOTE: should be moved bellow, just before getDispatcher().process(...)
        RackResponseEnvironment responseEnv = new ServletRackResponseEnvironment(httpResponse);

        if (isDoDispatch(requestCapture, responseCapture, chain, env, responseEnv)) {
            getDispatcher().process(env, responseEnv);
        }

    }

    /**
     * Destroys the {@link #getDispatcher()} by default.
     * @see Filter#destroy()
     */
    @Override
    public void destroy() {
        getDispatcher().destroy();
    }

    /**
     * Some filters may want to by-pass the rack application.  By default, all
     * requests are given to the {@link RackDispatcher}, but you can extend
     * this method and return false if you want to signal that you don't want
     * the {@link RackDispatcher} to see the request.
     *
     * @param request the request
     * @param response the response
     * @param chain the FilterChain
     * @param env the RackEnvironent
     * @return true if the dispatcher should handle the request, false if it
     * shouldn't.
     * @throws IOException if there's an IO exception
     * @throws ServletException if there's a servlet exception
     */
    protected boolean isDoDispatch(
            RequestCapture request, ResponseCapture response,
            FilterChain chain, RackEnvironment env)
            throws IOException, ServletException {
        return true;
    }

    /**
     * @deprecated use {@link #isDoDispatch(RequestCapture, ResponseCapture, FilterChain, RackEnvironment)}
     * @param request the request
     * @param response the response
     * @param chain the FilterChain
     * @param env the RackEnvironent
     * @param responseEnv the RackResponseEnvironment
     * @return isDoDispatch
     * @throws IOException if there's an IO exception
     * @throws ServletException if there's a servlet exception
     */
    @Deprecated
    protected boolean isDoDispatch(
            RequestCapture request, ResponseCapture response,
            FilterChain chain, RackEnvironment env,
            RackResponseEnvironment responseEnv)
            throws IOException, ServletException {
        return isDoDispatch(request, response, chain, env);
    }

    /**
     * Extension point if you'll need to customize {@link RequestCapture}
     * @param request the request
     * @return request capture
     */
    protected RequestCapture wrapRequest(ServletRequest request) {
        return new RequestCapture((HttpServletRequest) request);
    }

    /**
     * Extension point if you'll need to customize {@link ResponseCapture}
     * @param response the response
     * @return response capture
     */
    protected ResponseCapture wrapResponse(ServletResponse response) {
        return new ResponseCapture((HttpServletResponse) response);
    }

}
