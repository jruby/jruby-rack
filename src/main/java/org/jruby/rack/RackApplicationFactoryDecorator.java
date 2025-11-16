/*
 * The MIT License
 *
 * Copyright (c) 2012-2014 Karol Bucek LTD.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package org.jruby.rack;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

import org.jruby.Ruby;

import static org.jruby.rack.RackLogger.Level.DEBUG;

/**
 * An abstract base class for decorating factories.
 *
 * @see SharedRackApplicationFactory
 * @see PoolingRackApplicationFactory
 *
 * @author kares
 */
public abstract class RackApplicationFactoryDecorator
    implements RackApplicationFactory, RackApplicationFactory.Decorator {

    private final RackApplicationFactory delegate;
    private volatile RackContext context;
    private volatile RuntimeException initError;

    protected RackApplicationFactoryDecorator(RackApplicationFactory delegate) {
        this.delegate = delegate;
    }

    /**
     * @return the (decorated) delegate factory instance
     */
    @Override
    public RackApplicationFactory getDelegate() {
        return delegate;
    }

    @Deprecated
    public RackApplicationFactory getRealFactory() {
        return getDelegate();
    }

    public RackContext getContext() {
        return context;
    }

    public void setContext(RackContext context) {
        this.context = context;
    }

    public RackContext getRackContext() { // alias - backwards compat
        return context;
    }

    /**
     * @return the initialization error if any
     * @see #getApplication()
     */
    public RuntimeException getInitError() {
        return initError;
    }

    /**
     * Allows to set the initialization error for concrete factories.
     * @param initError the initialization error to raise
     * @see #getApplication()
     */
    protected synchronized void setInitError(RuntimeException initError) {
        this.initError = initError;
    }

    /**
     * @see RackApplicationFactory#init(RackContext)
     * @param context the current RackContext
     * @throws RackInitializationException if there's an error while initializing
     */
    @Override
    public void init(final RackContext context) throws RackInitializationException {
        setContext(context);
        try {
            doInit();
        }
        catch (Exception e) {
            throw initError = RackInitializationException.wrap(e);
        }
    }

    /**
     * Perform the initialization for this factory.
     * @throws Exception if there's an exception
     */
    protected void doInit() throws Exception {
        getDelegate().init(context);
    }

    /**
     * @see RackApplicationFactory#destroy()
     */
    @Override
    public void destroy() {
        getDelegate().destroy();
    }

    /**
     * The base implementation checks for an {@link #getInitError()} and if
     * there's one it throws the set exception as it assumes a rack application
     * can not be used if there was a runtime failure while initializing it's
     * factory.
     * @see RackApplicationFactory#getApplication()
     * @see #getApplicationImpl()
     * @throws RackException if there is a failure to initialize
     */
    @Override
    public RackApplication getApplication() throws RackException {
        final RuntimeException error = getInitError();
        if ( error != null ) {
            log(DEBUG, "due to a previous initialization failure application instance can not be returned");
            throw error;
        }
        return getApplicationImpl();
    }

    /**
     * Retrieves an initialized application instance.
     * @return the application instance
     */
    protected abstract RackApplication getApplicationImpl();

    /**
     * @see RackApplicationFactory#getErrorApplication()
     */
    @Override
    public RackApplication getErrorApplication() {
        return getDelegate().getErrorApplication();
    }

    /**
     * @return the config from the {@link #getContext()}
     */
    protected RackConfig getConfig() {
        return getContextBang().getConfig();
    }

    /**
     * Log a message.
     * @param level the logger level
     * @param message the log message
     */
    protected void log(final RackLogger.Level level, final String message) {
        getContextBang().log(level, message);
    }

    @Deprecated
    protected void log(final String level, final String message) {
        getContextBang().log(level, message);
    }

    /**
     * Log a message (and an exception).
     * @param level the logger level
     * @param message the log message
     * @param e the exception raised
     */
    protected void log(final RackLogger.Level level, final String message, Exception e) {
        getContextBang().log(level, message, e);
    }

    @Deprecated
    protected void log(final String level, final String message, Exception e) {
        getContextBang().log(level, message, e);
    }

    private RackContext getContextBang() throws IllegalStateException {
        final RackContext context = getContext();
        if ( context == null ) throw new IllegalStateException("no context");
        return context;
    }

    public abstract Collection<RackApplication> getManagedApplications() ;

    public static Collection<Ruby> getManagedRuntimes(RackApplicationFactoryDecorator factory) {
        final Collection<RackApplication> apps = factory.getManagedApplications();
        if ( apps == null ) return null;
        final Set<Ruby> runtimes = new LinkedHashSet<>(apps.size());
        for ( RackApplication app : apps ) {
            runtimes.add( app.getRuntime() );
        }
        return runtimes;
    }

}
