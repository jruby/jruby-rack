/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.*;
import java.util.stream.Collectors;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletResponse;

import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;

/**
 * UnappedRackFilter does dispatching to Ruby but does not alter the request
 * URI or attempt to map to an available static resource.
 *
 * Supports the following initialization parameters :
 *
 * * {@code resetUnhandledResponse} with accepted values: "true"/"false"/"buffer"
 *   controls the response behavior after it has been passed to the chain and
 *   got back unhandled, the filter than decides whether the response is going
 *   to get {@code reset()} or not (or {@code resetBuffer()}).
 *
 * @see RackFilter
 *
 * @author nicksieger
 */
public class UnmappedRackFilter extends AbstractFilter {

    private static final String RESET_BUFFER_VALUE = "buffer";

    // NOTE: it's true by default for backwards compatibility
    private Object resetUnhandledResponse = Boolean.TRUE;

    private boolean responseHandledByDefault = true;

    private static final Collection<Integer> RESPONSE_NOT_HANDLED_STATUSES;
    static {
        final Set<Integer> statuses = new HashSet<>(8, 1);
        statuses.add(404);
        // 403 due containers not supporting PUT/DELETE correctly (Tomcat 6)
        statuses.add(403);
        // 405 returned by Jetty 7/8 on PUT/DELETE requests by default
        statuses.add(405);
        // 501 is returned for non standard http verbs like PATCH
        statuses.add(501);
        RESPONSE_NOT_HANDLED_STATUSES = Collections.unmodifiableSet(statuses);
    }

    private Collection<Integer> responseNotHandledStatuses = RESPONSE_NOT_HANDLED_STATUSES;
    private RackContext context;
    private RackDispatcher dispatcher;

    public UnmappedRackFilter() { /* constructor used by container */ }

    /**
     * Dependency-injected constructor for testing
     * @param dispatcher the dispatcher
     * @param context the context
     */
    public UnmappedRackFilter(RackDispatcher dispatcher, RackContext context) {
        this.context = context;
        this.dispatcher = dispatcher;
    }

    /**
     * Construct a new dispatcher with the servlet context
     */
    @Override
    public void init(FilterConfig config) throws ServletException {
        this.context = (RackContext)
            config.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
        this.dispatcher = new DefaultRackDispatcher(this.context);

        // true / false / "buffer"
        String value = config.getInitParameter("resetUnhandledResponse");
        if ( value != null ) setResetUnhandledResponseValue(value);

        // ResponseCapture.notHandledStatuses e.g. "403,404,500"
        value = config.getInitParameter("responseNotHandledStatuses");
        if ( value != null ) {
            responseNotHandledStatuses = Arrays.stream(value.split(",")).
                    map(String::trim)
                    .filter(status -> !status.isEmpty())
                    .map(Integer::parseInt)
                    .collect(Collectors.toSet());
        }
        // ResponseCapture.handledByDefault true/false (true by default)
        value = config.getInitParameter("responseHandledByDefault");
        if ( value != null ) {
            responseHandledByDefault = Boolean.parseBoolean(value);
        }
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
    protected boolean isDoDispatch(
            final RequestCapture requestCapture,
            final ResponseCapture responseCapture,
            final FilterChain chain,
            final RackEnvironment env) throws IOException, ServletException {
        try {
            doFilterInternal(requestCapture, responseCapture, chain, env);
        } // some AppServers (WAS 8.0) seem to be chained up too smart @see #79
        catch (FileNotFoundException e) {
            responseCapture.setStatus(404);
        }
        return handleChainResponse(requestCapture, responseCapture);
    }

    protected void doFilterInternal(
            final RequestCapture requestCapture,
            final ResponseCapture responseCapture,
            final FilterChain chain,
            final RackEnvironment env) throws IOException, ServletException {
        chain.doFilter(requestCapture, responseCapture);
    }

    /**
     * Handle the filter chain response before dispatching the request.
     * @param request the request
     * @param response the response
     * @return true if the dispatcher should do a dispatch (to rails), otherwise
     * it is assumed that the request has been handled somewhere down the chain.
     * @throws IOException if there's an IOException
     */
    protected boolean handleChainResponse(RequestCapture request, ResponseCapture response)
        throws IOException {
        if ( ! response.isHandled(request) ) {
            request.reset(); // rewinds input stream
            // users might configure what to do on a 404 - by default we reset :
            if ( isResetUnhandledResponse() ) {
                response.reset();
            }
            else if ( isResetUnhandledResponseBuffer() ) {
                response.resetBuffer();
            }
            request.setAttribute(RackEnvironment.DYNAMIC_REQS_ONLY, Boolean.TRUE);
            return true; // dispatch (rails) - nobody handled the request
        }
        // do not dispatch if a filter set a 2xx/3xx response already ... or
        // decided to send an error (!= 404) e.g. as an authentication failure
        return false;
    }

    @Override
    protected ResponseCapture wrapResponse(ServletResponse response) {
        final ResponseCapture capture = super.wrapResponse(response);
        capture.setNotHandledStatuses( getResponseNotHandledStatuses() );
        capture.setHandledByDefault( isResponseHandledByDefault() );
        return capture;
    }

    // getters - setters :

    public boolean isResetUnhandledResponse() {
        return resetUnhandledResponse == Boolean.TRUE;
    }

    public void setResetUnhandledResponse(boolean reset) {
        this.resetUnhandledResponse = reset;
    }

    public boolean isResetUnhandledResponseBuffer() {
        return resetUnhandledResponse == RESET_BUFFER_VALUE;
    }

    public void setResetUnhandledResponseBuffer(boolean reset) {
        this.resetUnhandledResponse = reset ? RESET_BUFFER_VALUE : null;
    }

    protected void setResetUnhandledResponseValue(final String value) {
        if ( RESET_BUFFER_VALUE.equalsIgnoreCase(value) ) {
            this.resetUnhandledResponse = RESET_BUFFER_VALUE;
        }
        else {
            this.resetUnhandledResponse = Boolean.valueOf(value);
        }
    }

    public Collection<Integer> getResponseNotHandledStatuses() {
        return this.responseNotHandledStatuses;
    }

    public void setDefaultNotHandledStatuses(final Collection<Integer> responseNotHandledStatuses) {
        this.responseNotHandledStatuses =
            responseNotHandledStatuses == null ? Collections.emptySet() : responseNotHandledStatuses;
    }

    public boolean isResponseHandledByDefault() {
        return responseHandledByDefault;
    }

    public void setResponseHandledByDefault(boolean responseHandledByDefault) {
        this.responseHandledByDefault = responseHandledByDefault;
    }

}
