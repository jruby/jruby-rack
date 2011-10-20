package org.jruby.rack;

import javax.servlet.ServletConfig;


public class RackServlet extends AbstractServlet {

    private RackDispatcher dispatcher;
    private RackContext context;

    /** Default constructor for servlet container */
    public RackServlet() {
    }
    
    /** dependency injection ctor, used by unit tests */
    public RackServlet(RackDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Override
    public void init(ServletConfig config) {
        if (dispatcher == null) {
            context = (RackContext) config.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
            dispatcher = new DefaultRackDispatcher(context);
        }
    }

    @Override
    public RackDispatcher getDispatcher() {
        return dispatcher;
    }

    public RackContext getContext() {
        return context;
    }
    
}
