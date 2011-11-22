package org.jruby.rack.embed;

import javax.servlet.ServletConfig;

import org.jruby.rack.AbstractServlet;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackDispatcher;

public class Servlet extends AbstractServlet {

    private final Dispatcher dispatcher;
    private final Context context;

    public Servlet(Dispatcher dispatcher, Context context) {
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

    @Override
    public void init(ServletConfig config) {
        // NOOP
    }
    
}
