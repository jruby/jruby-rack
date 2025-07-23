/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.embed;

import java.io.PrintStream;

import org.jruby.rack.RackContext;
import org.jruby.rack.RackLogger;

import static org.jruby.rack.logging.OutputStreamLogger.printMessage;

/**
 * A context for embedded scenarios.
 */
public class Context implements RackContext, RackLogger {

    private final String serverInfo;
    private final Config config;

    /**
     * @param serverInfo a string to describe the server software you have
     * embedded. Exposed as a CGI variable.
     */
    public Context(final String serverInfo) {
        this(serverInfo, new Config());
    }

    /**
     * @param serverInfo a string to describe the server software you have
     * @param config rack configuration
     */
    public Context(final String serverInfo, final Config config) {
        if ( config == null ) {
            throw new IllegalArgumentException("null config");
        }
        this.serverInfo = serverInfo;
        this.config = config;

        this.logger = config.getLogger();
        if ( logger == null ) this.logger = new DefaultLogger();
    }

    @Override
    public String getServerInfo() {
        return this.serverInfo;
    }

    @Override
    public Config getConfig() {
        return this.config;
    }

    // RackLogger :

    private RackLogger logger;
    private Level level;

    public Level getLevel() {
        return level;
    }

    public void setLevel(Level level) {
        this.level = level;
    }

    @Override
    public void log(String message) {
        logger.log(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        logger.log(message, ex);
    }

    @Override
    public void log(Level level, String message) {
        if ( isEnabled(level) ) logger.log(level, message);
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        if ( isEnabled(level) ) logger.log(level, message, ex);
    }

    @Override @Deprecated
    public void log(String level, String message) {
        log(Level.valueOf(level), message);
    }

    @Override @Deprecated
    public void log(String level, String message, Throwable ex) {
        log(Level.valueOf(level), message, ex);
    }

    @Override
    public boolean isEnabled(Level level) {
        if ( level == null || this.level == null ) return true;
        return this.level.ordinal() <= level.ordinal();
    }



    private class DefaultLogger extends RackLogger.Base {

        @Override
        public void log(Level level, String message) {
            final PrintStream out = config.getOut();
            out.print(level); out.print(": ");
            printMessage(out, message);
        }

        @Override
        public void log(Level level, String message, Throwable ex) {
            final PrintStream err = config.getErr();
            err.print(level); err.print(": ");
            printMessage(err, message);
            ex.printStackTrace(err);
        }

        @Override
        public boolean isEnabled(Level level) { return true; }

        @Override
        public Level getLevel() { return null; /* unknown */ }

    }

}
