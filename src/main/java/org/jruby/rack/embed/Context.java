/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.embed;

import java.io.PrintStream;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackContext;

public class Context implements RackContext {

    private final String serverInfo;
    private final Config config;

    /**
     * @param serverInfo a string to describe the server software you have
     * embedded. Exposed as a CGI variable.
     */
    public Context(String serverInfo) {
        this(serverInfo, new Config());
        //this.config.setLogger(this);
    }

    /**
     * @param serverInfo
     * @param config rack configuration
     */
    public Context(String serverInfo, Config config) {
        if (config == null) {
            throw new IllegalArgumentException("null config");
        }
        this.serverInfo = serverInfo;
        this.config = config;
    }

    /**
     * @deprecated please use {@link #Context(String, Config)}
     */
    @Deprecated
    public Context(String serverInfo, RackConfig config) {
        this(serverInfo, new Config(config));
    }
    
    public String getServerInfo() {
        return this.serverInfo;
    }
    
    public Config getConfig() {
        return this.config;
    }

    // RackLogger :
    
    public void log(String message) {
        config.getOut().println(message);
    }

    public void log(String message, Throwable ex) {
        final PrintStream err = config.getErr();
        err.println(message);
        ex.printStackTrace(err);
    }
    
}
