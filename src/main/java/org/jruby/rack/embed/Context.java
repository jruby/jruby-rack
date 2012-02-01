/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.embed;

import org.jruby.rack.DefaultRackConfig;
import org.jruby.rack.RackConfig;

public class Context implements org.jruby.rack.RackContext {

    private final String serverInfo;
    private final DefaultRackConfig config;

    /**
     * @param serverInfo a string to describe the server software you have
     * embedded.  Exposed as a CGI variable.
     */
    public Context(String serverInfo) {
        this.serverInfo = serverInfo;
        this.config = new DefaultRackConfig();
    }

    public RackConfig getConfig() {
        return this.config;
    }

    public String getServerInfo() {
        return this.serverInfo;
    }

    public void log(String message) {
        System.out.println(message);
    }

    public void log(String message, Throwable ex) {
        System.err.println(message);
        ex.printStackTrace(System.err);
    }
}
