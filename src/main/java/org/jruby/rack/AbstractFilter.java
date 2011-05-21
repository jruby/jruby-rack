package org.jruby.rack;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.rack.servlet.ServletRackEnvironment;
import org.jruby.rack.servlet.ServletRackResponseEnvironment;

public abstract class AbstractFilter implements Filter {

  public final void doFilter(ServletRequest req, ServletResponse resp,
      FilterChain chain) throws IOException, ServletException {

    HttpServletRequest httpReq = (HttpServletRequest) req;
    HttpServletResponse httpResp = (HttpServletResponse) resp;

    RackEnvironment env = new ServletRackEnvironment(httpReq, getContext());
    RackResponseEnvironment respEnv = new ServletRackResponseEnvironment(httpResp);

    if (doDispatch(httpReq, httpResp, chain, env, respEnv)) {
        getDispatcher().process(env, respEnv);
    }

  }

  protected boolean doDispatch(HttpServletRequest req, HttpServletResponse resp,
      FilterChain chain, RackEnvironment env, RackResponseEnvironment respEnv) throws IOException, ServletException {
    return true;
  }

  protected abstract RackContext getContext();
  protected abstract RackDispatcher getDispatcher();

}
