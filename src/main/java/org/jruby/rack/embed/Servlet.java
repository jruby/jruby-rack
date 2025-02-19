/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.embed;

import jakarta.servlet.ServletConfig;

import org.jruby.rack.AbstractServlet;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackDispatcher;

@SuppressWarnings("serial")
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
