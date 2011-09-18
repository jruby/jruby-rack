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

  public final void doFilter(ServletRequest req, ServletResponse resp,
      FilterChain chain) throws IOException, ServletException {

    RequestCapture httpReq   = new RequestCapture((HttpServletRequest) req, getContext().getConfig());
    ResponseCapture httpResp = new ResponseCapture((HttpServletResponse) resp);

    RackEnvironment env             = new ServletRackEnvironment(httpReq, httpResp, getContext());
    RackResponseEnvironment respEnv = new ServletRackResponseEnvironment(httpResp);

    if (isDoDispatch(httpReq, httpResp, chain, env, respEnv)) {
        getDispatcher().process(env, respEnv);
    }
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
  protected boolean isDoDispatch(RequestCapture req, ResponseCapture resp,
      FilterChain chain, RackEnvironment env, RackResponseEnvironment respEnv) throws IOException, ServletException {
    return true;
  }

  protected abstract RackContext getContext();
  protected abstract RackDispatcher getDispatcher();

}
