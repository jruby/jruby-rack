package org.jruby.rack;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;
import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

public abstract class AbstractFilter implements Filter {
    
    public final void doFilter(
            ServletRequest request, ServletResponse response,
            FilterChain chain) throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        
        RequestCapture requestCapture = wrapRequest(httpRequest);
        ResponseCapture responseCapture = wrapResponse(httpResponse);
        
        RackEnvironment env = new ServletRackEnvironment(httpRequest, httpResponse, getContext());
        RackResponseEnvironment responseEnv = new ServletRackResponseEnvironment(httpResponse);

        if (isDoDispatch(requestCapture, responseCapture, chain, env, responseEnv)) {
            getDispatcher().process(env, responseEnv);
        }

    }

    @Override
    public void destroy() {
        getDispatcher().destroy();
    }
    
    /**
     * Some filters may want to by-pass the rack application.  By default, all
     * requests are given to the {@link RackDispatcher}, but you can extend
     * this method and return false if you want to signal that you don't want
     * the {@link RackDispatcher} to see the request.
    
     * @return true if the dispatcher should handle the request, false if it
     * shouldn't.
     * @throws IOException
     * @throws ServletException
     */
    protected boolean isDoDispatch(
            RequestCapture request, ResponseCapture response,
            FilterChain chain, RackEnvironment env,
            RackResponseEnvironment respEnv) throws IOException, ServletException {
        return true;
    }

    protected abstract RackContext getContext();

    protected abstract RackDispatcher getDispatcher();
    
    protected RequestCapture wrapRequest(ServletRequest request) {
        return new RequestCapture((HttpServletRequest) request, getContext().getConfig());
    }

    protected ResponseCapture wrapResponse(ServletResponse response) {
        return new ResponseCapture((HttpServletResponse) response);
    }
    
}
