/*
 * Copyright (c) 2010-2011 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.io.IOException;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;

import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;

/**
 * UnappedRackFilter does dispatching to Ruby but does not alter the request
 * URI or attempt to map to an available static resource.
 * @author nicksieger
 */
public class UnmappedRackFilter extends AbstractFilter {

    private RackContext context;
    private RackDispatcher dispatcher;

    /** Default constructor for servlet container */
    public UnmappedRackFilter() {
    }

    /** Dependency-injected constructor for testing */
    public UnmappedRackFilter(RackDispatcher dispatcher, RackContext context) {
        this.context = context;
        this.dispatcher = dispatcher;
    }

    /** Construct a new dispatcher with the servlet context */
    @Override
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
    protected boolean isDoDispatch(
            RequestCapture requestCapture, ResponseCapture responseCapture,
            FilterChain chain, RackEnvironment env,
            RackResponseEnvironment responseEnv) throws IOException, ServletException {
        
        chain.doFilter(requestCapture, responseCapture);
        
        return handleError(requestCapture, responseCapture);
    }
    
    protected boolean handleError(RequestCapture request, ResponseCapture response) 
            throws IOException {
        final boolean error = response.isError();
        if (error) {
            request.reset();
            response.reset();
            request.setAttribute(RackEnvironment.DYNAMIC_REQS_ONLY, Boolean.TRUE);
        }
        return error;        
    }
    
}
