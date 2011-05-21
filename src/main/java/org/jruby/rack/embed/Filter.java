package org.jruby.rack.embed;


import javax.servlet.FilterConfig;
import javax.servlet.ServletException;

import org.jruby.rack.AbstractFilter;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackDispatcher;

public class Filter extends AbstractFilter {

  private Dispatcher dispatcher;
  private final Context context;

  public Filter(Dispatcher dispatcher, Context context) {
    this.dispatcher = dispatcher;
    this.context = context;
  }

  @Override
  protected RackContext getContext() {
    return this.context;
  }

  @Override
  protected RackDispatcher getDispatcher() {
    return this.dispatcher;
  }

  public void destroy() { }
  public void init(FilterConfig arg0) throws ServletException { }

}
