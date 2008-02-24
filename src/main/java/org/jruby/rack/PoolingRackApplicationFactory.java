/*
 ***** BEGIN LICENSE BLOCK *****
 * Version: CPL 1.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Common Public
 * License Version 1.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/cpl-v10.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2007 Sun Microsystems, Inc.
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the CPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the CPL, the GPL or the LGPL.
 ***** END LICENSE BLOCK *****/

package org.jruby.rack;

import java.util.LinkedList;
import java.util.Queue;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;

/**
 * A pooling application factory that creates runtimes and manages a fixed- or
 * unlimited-size pool.
 * <p>
 * It has several context init parameters to control behavior:
 * <ul>
 * <li> jruby.initial.runtimes: Initial number of runtimes to create and put in
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

    private ServletContext servletContext;
    private RackApplicationFactory realFactory;
    private Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer initial, maximum;
    private long timeout = DEFAULT_TIMEOUT;
    private Semaphore permits;
    
    public PoolingRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public void init(final ServletContext servletContext) throws ServletException {
        this.servletContext = servletContext;
        realFactory.init(servletContext);

        Integer specifiedTimeout = getPositiveInteger(servletContext, 
                "jruby.runtime.timeout.sec");
        if (specifiedTimeout != null) {
            timeout = specifiedTimeout.longValue();
        }
        servletContext.log("Using runtime pool timeout of " + timeout + " seconds");

        initial = getInitial(servletContext);
        maximum = getMaximum(servletContext);

        if (initial != null) {
            fillInitialPool(servletContext);
        }

        if (maximum != null) {
            if (initial != null && initial > maximum) {
                maximum = initial;
            }
            permits = new Semaphore(maximum, true); // does fairness matter?
        }
    }

    public RackApplication newApplication() throws RackInitializationException {
        return getApplication();
    }

    public RackApplication getApplication() throws RackInitializationException {
        if (permits != null) {
            try {
                permits.tryAcquire(timeout, TimeUnit.SECONDS);
            } catch (InterruptedException ex) {
                throw new RackInitializationException("timeout: all listeners busy", ex);
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

    public void destroy() {
        synchronized (applicationPool) {
            for (RackApplication app : applicationPool) {
                app.destroy();
            }
        }
    }

    /** Used only by unit tests */
    public Queue<RackApplication> getApplicationPool() {
        return applicationPool;
    }

    /** This creates the application objects in the foreground thread to avoid
     * leakage when the web application is undeployed from the application server. */
    private void fillInitialPool(final ServletContext servletContext) throws ServletException {
        final Queue<RackApplication> apps = new LinkedList<RackApplication>();
        for (int i = 0; i < initial; i++) {
            try {
                apps.add(realFactory.newApplication());
            } catch (RackInitializationException ex) {
                throw new ServletException("unable to create application for pool", ex);
            }
        }

        Integer numThreads = getPositiveInteger(servletContext,
                "jruby.runtime.initializer.threads");
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
                                applicationPool.add(app);
                                servletContext.log("add application to the pool. size now = "
                                        + applicationPool.size());
                                applicationPool.notifyAll();
                            }
                        }
                    } catch (RackInitializationException ex) {
                        servletContext.log("unable to initialize application", ex);
                    }
                }
            }, "JRuby-Rack-App-Init-" + i).start();
        }

        try {
            synchronized (applicationPool) {
                if (applicationPool.isEmpty()) {
                    // Wait 30 seconds or until first runtime is available
                    applicationPool.wait(DEFAULT_TIMEOUT * 1000);
                }
            }
        } catch (InterruptedException ex) {
        }
    }

    private Integer getMaximum(ServletContext servletContext) {
        return getRangeValue(servletContext, "max", "maxActive");
    }

    private Integer getInitial(ServletContext servletContext) {
        return getRangeValue(servletContext, "initial", "minIdle");
    }

    private Integer getRangeValue(ServletContext servletContext, String end, String gsValue) {
        Integer v = getPositiveInteger(servletContext, "jruby." + end + ".runtimes");
        if (v == null) {
            v = getPositiveInteger(servletContext, "jruby.pool." + gsValue);
        }
        if (v == null) {
            servletContext.log("warning: no " + end + " runtimes specified.");
        } else {
            servletContext.log("received " + end + " runtimes = " + v);
        }
        return v;
    }

    private Integer getPositiveInteger(ServletContext servletContext, String string) {
        try {
            int i = Integer.parseInt(servletContext.getInitParameter(string));
            if (i > 0) {
                return new Integer(i);
            }
        } catch (Exception e) {
        }
        return null;
    }
}
