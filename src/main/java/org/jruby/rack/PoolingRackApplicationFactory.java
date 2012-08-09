/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack;

import java.util.Collection;
import java.util.Collections;
import java.util.LinkedList;
import java.util.Queue;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

/**
 * A pooling application factory that creates runtimes and manages a fixed- or
 * unlimited-size pool.
 * <p>
 * It has several context init parameters to control behavior:
 * <ul>
 * <li> jruby.min.runtimes: Initial number of runtimes to create and put in
 *  the pool. Default is none.
 * <li> jruby.max.runtimes: Maximum size of the pool. Default is unlimited, in
 *  which case new requests for an application object will create one if none
 *  are available.
 * <li> jruby.runtime.timeout.sec: Value (in seconds) indicating when
 *  a thread will timeout when no runtimes are available. Default is 30.
 * <li> jruby.runtime.initializer.threads: Number of threads to use at startup to
 *  intialize and fill the pool. Default is 4.
 * </ul>
 *
 * @author nicksieger
 */
public class PoolingRackApplicationFactory implements RackApplicationFactory {
    
    static final int DEFAULT_TIMEOUT = 30;
    
    protected RackContext rackContext;
    private final RackApplicationFactory realFactory;
    
    protected final Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer initial, maximum;
    
    private int acquireTimeout = DEFAULT_TIMEOUT;
    private Semaphore permits;

    public PoolingRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public RackApplicationFactory getRealFactory() {
        return realFactory;
    }
    
    public RackContext getRackContext() {
        return rackContext;
    }
    
    public Collection<RackApplication> getApplicationPool() {
        return Collections.unmodifiableCollection(applicationPool);
    }
    
    public void init(final RackContext rackContext) throws RackInitializationException {
        this.rackContext = rackContext;
        realFactory.init(rackContext);

        final RackConfig config = rackContext.getConfig();
        Integer timeout = config.getRuntimeTimeoutSeconds();
        if (timeout != null) {
            this.acquireTimeout = timeout;
        }

        initial = config.getInitialRuntimes();
        maximum = config.getMaximumRuntimes();
        
        rackContext.log(RackLogger.INFO, "using "+ initial + ":"+ 
                ( maximum == null ? "" : maximum ) +
                " runtime pool with acquire timeout of "+ timeout +" seconds");
        
        if (maximum != null) {
            if (initial != null && initial > maximum) {
                maximum = initial;
            }
            permits = new Semaphore(maximum, true); // does fairness matter?
        }
        if (initial != null) {
            fillInitialPool();
        }
    }

    /**
     * Same as {@link #getApplication()} since we're pooling instances.
     * @see RackApplicationFactory#newApplication() 
     */
    public RackApplication newApplication() throws RackInitializationException {
        return getApplication();
    }

    /**
     * Returns an application instance from the pool.
     * If no instances in pool attempts to wait a specified timeout of seconds.
     * Creates a new instance on demand if the pool is not limited with a 
     * upper maximum.
     * @see RackApplicationFactory#getApplication() 
     */
    public RackApplication getApplication() throws RackInitializationException {
        final boolean permit = acquireApplicationPermit();
        
        synchronized (applicationPool) {
            if ( ! applicationPool.isEmpty() ) {
                return applicationPool.remove();
            }
        }
        
        if ( ! permit ) {
            rackContext.log(RackLogger.INFO, "pool was empty - getting new application instance");
            // we're try to put it "back" to pool from finishedWithApplication(app)
            return realFactory.getApplication();
        }
        
        // if permit == true we should have succeeded getting from the pool
        rackContext.log(RackLogger.ERROR, "permit acquired but pool was empty");
        throw new IllegalStateException("permit acquired but pool was empty");
    }

    /**
     * @return true if a permit is acquired, false if no permit necessary
     * @throws TimeoutException if a permit can not be acquired
     */
    protected boolean acquireApplicationPermit() throws RackInitializationException {
        // NOTE: permits are only used if a pool maximum is specified !
        if (permits != null) {
            boolean acquired = false;
            try {
                acquired = permits.tryAcquire(acquireTimeout, TimeUnit.SECONDS);
            }
            catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RackInitializationException("could not acquire application permit", e);
            }
            
            if ( ! acquired ) {
                throw new RackInitializationException("could not acquire application permit" + 
                        ", within " + acquireTimeout + " seconds");
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
            rackContext.log(RackLogger.WARN, "ignoring null application");
            return;
        }
        synchronized (applicationPool) {
            if (maximum != null && applicationPool.size() >= maximum) {
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
     * @see RackApplicationFactory#getErrorApplication() 
     */
    public RackApplication getErrorApplication() {
        return realFactory.getErrorApplication();
    }

    /**
     * @see RackApplicationFactory#destroy() 
     */
    public void destroy() {
        synchronized (applicationPool) {
            for (RackApplication app : applicationPool) {
                app.destroy();
            }
            applicationPool.clear();
        }
        realFactory.destroy();
    }
    
    /**
     * Fills the initial pool with initialized application instances.
     * 
     * Application objects are created in foreground threads to avoid
     * leakage when the web application is undeployed from the server.
     */
    protected void fillInitialPool() throws RackInitializationException {
        Queue<RackApplication> apps = createApplications();
        launchInitializerThreads(apps);
        synchronized (applicationPool) {
            if (applicationPool.isEmpty()) {
                waitForNextAvailable(DEFAULT_TIMEOUT);
            }
        }
        // returns when there's at least 1 application initialized or 
        // 30 (DEFAULT_TIMEOUT) seconds had ellapsed since launch ...
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
        Integer numThreads = rackContext.getConfig().getNumInitializerThreads();
        if ( numThreads == null ) numThreads = 4; // quad-core baby
        
        for (int i = 0; i < numThreads; i++) {
            new Thread(new Runnable() {

                public void run() {
                    try {
                        while (true) {
                            final RackApplication app;
                            synchronized (apps) {
                                if (apps.isEmpty()) {
                                    break;
                                }
                                app = apps.remove();
                            }
                            app.init();
                            if ( ! putApplicationToPool(app) ) break;
                        }
                    }
                    catch (RackInitializationException e) {
                        rackContext.log(RackLogger.ERROR, "unable to initialize application", e);
                    }
                }
                
            }, "JRuby-Rack-App-Init-" + i).start();
        }
    }

    protected Queue<RackApplication> createApplications() throws RackInitializationException {
        Queue<RackApplication> apps = new LinkedList<RackApplication>();
        for (int i = 0; i < initial; i++) {
            apps.add(realFactory.newApplication());
        }
        return apps;
    }
    
    /** Called when a thread initialized an application. */
    private boolean putApplicationToPool(final RackApplication app) {
        synchronized (applicationPool) {
            if (maximum != null && applicationPool.size() >= maximum) {
                return false;
            }
            applicationPool.add(app);
            rackContext.log(RackLogger.INFO, "added application " + 
                    "to pool, size now = " + applicationPool.size());
            // in case we're waiting from waitForNextAvailable() :
            applicationPool.notifyAll();
        }
        return true;
    }
    
    /** Wait the specified time (in seconds) or until a runtime is available. */
    private void waitForNextAvailable(final int timeout) {
        synchronized (applicationPool) {
            try {
                // although applicationPool is "locked" here
                // calling wait() releases the target lock !
                applicationPool.wait(timeout * 1000);
            }
            catch (InterruptedException ignore) {
                return;
            }
        }
    }
    
}
