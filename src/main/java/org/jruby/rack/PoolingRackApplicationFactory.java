/*
 * Copyright 2007-2009 Sun Microsystems, Inc.
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
    private RackApplicationFactory realFactory;
    protected final Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer initial, maximum;
    private long timeout = DEFAULT_TIMEOUT;
    private Semaphore permits;

    public PoolingRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public void init(final RackContext rackContext) throws RackInitializationException {
        this.rackContext = rackContext;
        realFactory.init(rackContext);

        Integer specifiedTimeout = getPositiveInteger("jruby.runtime.timeout.sec");
        if (specifiedTimeout != null) {
            timeout = specifiedTimeout.longValue();
        }
        rackContext.log("Info: using runtime pool timeout of " + timeout + " seconds");

        initial = getInitial();
        maximum = getMaximum();
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

    public RackApplication newApplication() throws RackInitializationException {
        return getApplication();
    }

    public RackApplication getApplication() throws RackInitializationException {
        if (permits != null) {
            boolean acquired = false;
            try {
                acquired = permits.tryAcquire(timeout, TimeUnit.SECONDS);
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
            }
            if (!acquired) {
                throw new RackInitializationException("timeout: all listeners busy",
                        new InterruptedException());
            }
        }
        synchronized (applicationPool) {
            if (!applicationPool.isEmpty()) {
                return applicationPool.remove();
            }
        }

        return realFactory.getApplication();
    }

    public void finishedWithApplication(RackApplication app) {
        synchronized (applicationPool) {
            if (maximum != null && applicationPool.size() >= maximum) {
                return;
            }
            applicationPool.add(app);
            if (permits != null) {
                permits.release();
            }
        }
    }

    public RackApplication getErrorApplication() {
        return realFactory.getErrorApplication();
    }

    public void destroy() {
        synchronized (applicationPool) {
            for (RackApplication app : applicationPool) {
                app.destroy();
            }
        }
    }

    /** Used only by unit tests */
    public Collection<RackApplication> getApplicationPool() {
        return Collections.unmodifiableCollection(applicationPool);
    }

    /** This creates the application objects in the foreground thread to avoid
     * leakage when the web application is undeployed from the application server. */
    protected void fillInitialPool() throws RackInitializationException {
        Queue<RackApplication> apps = createApplications();
        launchInitializerThreads(apps);
        synchronized (applicationPool) {
            if (applicationPool.isEmpty()) {
                waitForNextAvailable(DEFAULT_TIMEOUT * 1000);
            }
        }
    }

    protected void launchInitializerThreads(final Queue<RackApplication> apps) {
        Integer numThreads = getPositiveInteger("jruby.runtime.initializer.threads");
        if (numThreads == null) {
            numThreads = 4;
        }

        for (int i = 0; i < numThreads; i++) {
            new Thread(new Runnable() {

                public void run() {
                    try {
                        while (true) {
                            RackApplication app = null;
                            synchronized (apps) {
                                if (apps.isEmpty()) {
                                    break;
                                }
                                app = apps.remove();
                            }
                            app.init();
                            synchronized (applicationPool) {
                                if (maximum != null && applicationPool.size() >= maximum) {
                                    break;
                                }
                                applicationPool.add(app);
                                rackContext.log("Info: add application to the pool. size now = " + applicationPool.size());
                                applicationPool.notifyAll();
                            }
                        }
                    } catch (RackInitializationException ex) {
                        rackContext.log("Error: unable to initialize application", ex);
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

    /** Wait the specified time or until a runtime is available. */
    public void waitForNextAvailable(long timeout) {
        try {
            synchronized (applicationPool) {
                applicationPool.wait(timeout);
            }
        } catch (InterruptedException ex) {
        }
    }

    private Integer getInitial() {
        return getRangeValue("min", "minIdle");
    }

    private Integer getMaximum() {
        return getRangeValue("max", "maxActive");
    }

    private Integer getRangeValue(String end, String gsValue) {
        Integer v = getPositiveInteger("jruby." + end + ".runtimes");
        if (v == null) {
            v = getPositiveInteger("jruby.pool." + gsValue);
        }
        if (v == null) {
            rackContext.log("Warning: no " + end + " runtimes specified.");
        } else {
            rackContext.log("Info: received " + end + " runtimes = " + v);
        }
        return v;
    }

    private Integer getPositiveInteger(String string) {
        try {
            int i = Integer.parseInt(rackContext.getInitParameter(string));
            if (i > 0) {
                return new Integer(i);
            }
        } catch (Exception e) {
        }
        return null;
    }
}
