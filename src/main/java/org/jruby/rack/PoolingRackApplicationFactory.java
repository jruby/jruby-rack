/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedList;
import java.util.Queue;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * A pooling application factory that creates applications (runtimes) and
 * manages a fixed-size (or upper unlimited-size) application pool.
 * <p>
 * It has several context initialization parameters to control behavior :
 * <ul>
 * <li><code>jruby.min.runtimes</code>:
 *  Initial number of runtimes to create and put in the pool. Default is none.
 * <li><code>jruby.max.runtimes</code>:
 *  Maximum size of the pool. Default is unlimited, in which case new requests
 *  for an application object will create one if none are available.
 * <li><code>jruby.runtime.acquire.timeout</code>: Value (in seconds)
 *  indicating when a thread will timeout waiting for an application instance
 *  when no runtimes are available in the pool. Default is 10.0 (seconds), an
 *  {@link AcquireTimeoutException} is thrown if such a condition occurs.
 * <li><code>jruby.runtime.init.threads</code>:
 *  Number of threads to use at startup to fill the pool. Default is 4.
 * <li><code>jruby.runtime.init.wait</code>:
 *  Whether to wait for initialization to complete before the factory is usable.
 *  In case it's a integer value it waits for until given number of application
 *  instances are in the pool. Default is true (waits till at least min runtimes
 *  are initialized).
 * </ul>
 *
 * @author nicksieger
 */
public class PoolingRackApplicationFactory extends RackApplicationFactoryDecorator {

    // 10 seconds seems still too much for a default, has been 30 previously :
    private static final float ACQUIRE_DEFAULT = 10.0f;

    protected final Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer initialSize, maximumSize;

    private final AtomicInteger initedApplications = new AtomicInteger(0);
    private final AtomicInteger createdApplications = new AtomicInteger(0);

    private float acquireTimeout = ACQUIRE_DEFAULT; // in seconds
    private Semaphore permits;

    public PoolingRackApplicationFactory(RackApplicationFactory delegate) {
        super(delegate);
    }

    /**
     * @return the (unmodifiable) pool snapshot
     */
    public Collection<RackApplication> getApplicationPool() {
        return applicationPool;
    }

    /**
     * @return <code>jruby.min.runtimes</code>
     */
    public Integer getInitialSize() {
        return initialSize;
    }

    public void setInitialSize(Integer initialSize) {
        this.initialSize = initialSize;
        if (initialSize != null && maximumSize != null && initialSize > maximumSize) {
            setMaximumSize(initialSize);
        }
    }

    /**
     * @return <code>jruby.max.runtimes</code>
     */
    public Integer getMaximumSize() {
        return maximumSize;
    }

    public void setMaximumSize(Integer maximumSize) {
        if (maximumSize != null && initialSize != null && initialSize > maximumSize) {
            maximumSize = initialSize;
        }
        this.maximumSize = maximumSize;
    }

    /**
     * @return the timeout to wait for the pool to return an application if empty
     */
    public Number getAcquireTimeout() {
        return acquireTimeout;
    }

    public void setAcquireTimeout(Number acquireTimeout) {
        this.acquireTimeout = acquireTimeout == null ?
            ACQUIRE_DEFAULT : acquireTimeout.floatValue();
    }

    @Override
    protected void doInit() throws Exception {
        super.doInit(); // delegate.init(rackContext);
        final RackConfig config = getConfig();
        // TODO until config.getRuntimeTimeoutSeconds returns an integer :
        Number timeout = config.getNumberProperty("jruby.runtime.acquire.timeout");
        if (timeout == null) { // backwards compatibility with 1.0.x :
            timeout = config.getNumberProperty("jruby.runtime.timeout.sec");
        }
        setAcquireTimeout( timeout );

        setInitialSize( config.getInitialRuntimes() );
        setMaximumSize( config.getMaximumRuntimes() );

        log( RackLogger.INFO, "using "+ // using 4:8 runtime pool
                ( initialSize == null ? "" : initialSize ) + ":" +
                ( maximumSize == null ? "" : maximumSize ) +
                " runtime pool with acquire timeout of " +
                acquireTimeout + " seconds" );

        fillInitialPool();
        RuntimeException error = getInitError();
        if ( error != null ) throw error; // an init thread failed
    }

    /**
     * Same as {@link #getApplication()} since we're pooling instances.
     * @see RackApplicationFactory#newApplication()
     */
    public RackApplication newApplication()
        throws RackInitializationException, AcquireTimeoutException {
        return getApplication();
    }

    /**
     * Returns an application instance from the pool.
     * If no instances in pool attempts to wait a specified timeout of seconds.
     * Creates a new instance on demand if the pool is not limited with an
     * upper maximum (or the upper bound has not been reached yet).
     * @see RackApplicationFactory#getApplication()
     */
    @Override
    protected RackApplication getApplicationImpl()
        throws RackInitializationException, AcquireTimeoutException {

        RackApplication app = null;
        final boolean permit = acquireApplicationPermit();
        // if a permit is gained we can retrieve an app from the pool
        synchronized (applicationPool) {
            if ( ! applicationPool.isEmpty() ) {
                app = applicationPool.remove();
            }
            else if ( permit && ( initialSize != null &&
                    initialSize > initedApplications.get() ) ) {
                // pool is empty but we still gained a permit for an app !
                // could only happen if the initialization threads are still
                // running (and we've been configured to not wait till all
                // 'initial' applications are put to the pool on #init())
                while (true) { // thus we'll wait for another pool put ...
                    waitForApplication();
                    if ( ! applicationPool.isEmpty() ) break;
                }
                app = applicationPool.remove();
            }
        }

        if ( app != null ) return app;
        // NOTE: for apps that take a long time to boot simply set values
        // initial == maximum to avoid creating an application on demand
        if ( ! permit || ( maximumSize == null || maximumSize > createdApplications.get() ) ) {
            log(RackLogger.INFO, "pool was empty - getting new application instance");
            // we'll try to put it "back" to pool from finishedWithApplication(app)
            return createApplication(true);
        }

        // NOTE: getting here means something is wrong (app == null) :
        throw new IllegalStateException("retrieved a null from the pool, " +
                "please check the log for previous initialization errors");
    }

    /**
     * @return true if a permit is acquired, false if no permit necessary
     * @throws TimeoutException if a permit can not be acquired
     */
    protected boolean acquireApplicationPermit() throws AcquireTimeoutException {
        // NOTE: permits are only used if a pool maximum is specified !
        if (permits != null) {
            boolean acquired = false;
            try {
                final long timeout = (long) (acquireTimeout * 1000);
                acquired = permits.tryAcquire(timeout, TimeUnit.MILLISECONDS);
                // if timeout <= 0 to zero, the method will not wait ...
            }
            catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new AcquireTimeoutException("could not acquire application permit", e);
            }

            if ( ! acquired ) {
                String message = "could not acquire application permit" +
                        " within " + acquireTimeout + " seconds";
                log(RackLogger.INFO, message + " (try increasing the pool size)");
                throw new AcquireTimeoutException(message);
            }
            return true; // acquired permit
        }
        return false; // no maximum limit - no permit needed
    }

    /**
     * @see RackApplicationFactory#finishedWithApplication(RackApplication)
     */
    public void finishedWithApplication(final RackApplication app) {
        if (app == null) {
            // seems to sometimes happen when an error occurs during boot
            // and thus on destroy app.destroy(); will fail with a NPE !
            log(RackLogger.WARN, "ignoring null application");
            return;
        }
        synchronized (applicationPool) {
            if (maximumSize != null && applicationPool.size() >= maximumSize) {
                return;
            }
            if (applicationPool.contains(app)) {
                return;
            }
            // return app to pool and signal it's usable to acquire :
            applicationPool.add(app);
            if (permits != null) {
                permits.release();
            }
        }
    }

    /**
     * @see RackApplicationFactory#destroy()
     */
    @Override
    public void destroy() {
        synchronized (applicationPool) {
            for (RackApplication app : applicationPool) {
                getDelegate().finishedWithApplication(app);
                // DefaultRackAppFactory: app.destroy();
            }
            applicationPool.clear();
        }
        super.destroy(); // delegate.destroy();
    }

    /**
     * Fills the initial pool with initialized application instances.
     *
     * Application objects are created in foreground threads to avoid
     * leakage when the web application is undeployed from the server.
     */
    public void fillInitialPool() throws RackInitializationException {
        permits = maximumSize != null ? new Semaphore(maximumSize, true) : null;
        if (initialSize != null) { // otherwise pool filled on demand
            Queue<RackApplication> apps = createApplications();
            launchInitializerThreads(apps);
            waitTillPoolReady();
        }
    }

    /**
     * @param apps
     * @deprecated override {@link #launchInitialization(java.util.Queue)}
     */
    @Deprecated
    protected void launchInitializerThreads(final Queue<RackApplication> apps) {
        launchInitialization(apps);
    }

    /**
     * Launches application initialization.
     * @param apps the (initial) instances (for the pool) to be initialized
     */
    protected void launchInitialization(final Queue<RackApplication> apps) {
        @SuppressWarnings("deprecation")
        Integer initThreads = getConfig().getNumInitializerThreads();
        if ( initThreads == null ) initThreads = 4; // quad-core baby

        for (int i = 0; i < initThreads; i++) {
            new Thread(new Runnable() {

                public void run() {
                    while (true) {
                        final RackApplication app;
                        synchronized (apps) {
                            if ( apps.isEmpty() ) break;
                            app = apps.remove();
                        }
                        if ( ! initAndPutApplicationToPool(app) ) break;
                    }
                }

            }, "JRuby-Rack-App-Init-" + i).start();
        }
    }

    private boolean initAndPutApplicationToPool(final RackApplication app) {
        try {
            app.init();
        }
        catch (final RuntimeException e) {
            synchronized(this) {
                RuntimeException initError = getInitError();
                setInitError(e);

                if ( initError == null ||
                   ! initError.getClass().equals(e.getClass()) ||
                   ! initError.getMessage().equals(e.getMessage()) ) {
                    log(RackLogger.ERROR, "unable to initialize application", e);
                }
            }
            // we're put a null to make sure we get notified :
            return putApplicationToPool(null);
        }
        return putApplicationToPool(app);
    }

    protected Queue<RackApplication> createApplications() throws RackInitializationException {
        Queue<RackApplication> apps = new LinkedList<RackApplication>();
        for (int i = 0; i < initialSize; i++) {
            apps.add( createApplication(false) );
        }
        return apps;
    }

    private synchronized RackApplication createApplication(final boolean init)
        throws RackInitializationException {
        createdApplications.incrementAndGet();
        if ( init ) initedApplications.incrementAndGet();
        return init ? getDelegate().getApplication() : getDelegate().newApplication();
    }

    /** Called when a thread initialized an application. */
    private boolean putApplicationToPool(final RackApplication app) {
        synchronized (applicationPool) {
            if (maximumSize != null && applicationPool.size() >= maximumSize) {
                return false;
            }
            applicationPool.add(app);
            log(RackLogger.INFO, "added application to pool, size now = " + applicationPool.size());
            initedApplications.incrementAndGet();
            // in case we're waiting from waitForNextAvailable() :
            applicationPool.notifyAll();
        }
        return true;
    }

    /** Wait till the pool has enough (initialized) applications. */
    protected void waitTillPoolReady() {
        final int waitFor = getInitialPoolSizeWait();
        while (true) {
            synchronized (applicationPool) {
                if ( applicationPool.size() >= waitFor ) break;
                waitForApplication();
            }
        }
    }

    private void waitForApplication() {
        synchronized (applicationPool) {
            try {
                // although applicationPool is "locked" here
                // calling wait() releases the target lock !
                applicationPool.wait(5 * 1000);
            }
            catch (InterruptedException ignore) {
                return;
            }
        }
    }

    /**
     * How many (initial) application instances to wait for becoming available
     * in the pool (less or equal than zero means not to wait at all).
     */
    private int getInitialPoolSizeWait() {
        Number waitNum = getConfig().getNumberProperty("jruby.runtime.init.wait");
        if ( waitNum != null ) {
            int wait = waitNum.intValue();
            if (maximumSize != null && wait > maximumSize) {
                wait = maximumSize.intValue();
            }
            return wait;
        }
        // otherwise we assume it to be a boolean true/false flag :
        Boolean waitFlag = getConfig().getBooleanProperty("jruby.runtime.init.wait");
        if ( waitFlag == null ) waitFlag = Boolean.TRUE;
        return waitFlag ? ( initialSize == null ? 1 : initialSize.intValue() ) : 0;
        // NOTE: this slightly changes the behavior in 1.1.8, in previous
        // versions the initialization only waited for 1 application instance
        // to be available in the pool - here by default we wait till initial
        // apps are ready to be used, or 1 (previous behavior) if initial null
    }

    @Override
    public Collection<RackApplication> getManagedApplications() {
        int initSize = initialSize != null ? initialSize.intValue() : -1;
        synchronized (applicationPool) {
            if ( applicationPool.isEmpty() ) {
                if ( initSize > 0 ) return null;
                return Collections.emptySet();
            }
            Collection<RackApplication> snapshot =
                    new ArrayList<RackApplication>(applicationPool);
            return Collections.unmodifiableCollection(snapshot);
        }
    }

}
