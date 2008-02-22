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

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;

/**
 *
 * @author nicksieger
 */
public class PoolingRackApplicationFactory implements RackApplicationFactory {
    static final int DEFAULT_TIMEOUT = 30;

    private ServletContext servletContext;
    private RackApplicationFactory realFactory;
    private Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer minimum, maximum;
    private long timeout = DEFAULT_TIMEOUT;
    private Semaphore permits;
    
    public PoolingRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public void init(final ServletContext servletContext) throws ServletException {
        realFactory.init(servletContext);
        this.servletContext = servletContext;

        timeout = DEFAULT_TIMEOUT;
        Integer specifiedTimeout = getPositiveInteger(servletContext, "jruby.runtime.timeout.sec");
        if (specifiedTimeout != null) {
            timeout = specifiedTimeout.longValue();
        }

        minimum = getMinimum(servletContext);
        maximum = getMaximum(servletContext);

        if (minimum != null) {
            List<Thread> threads = new ArrayList<Thread>();
            for (int i = 0; i < minimum; i++) {
                Thread t = new Thread(new Runnable() {
                    public void run() {
                        try {
                            final RackApplication app = realFactory.newApplication();
                            synchronized (applicationPool) {
                                applicationPool.add(app);
                                servletContext.log("add application to the pool. size now = " + applicationPool.size());
                            }
                        } catch (RackInitializationException ex) {
                            servletContext.log("unable to pre-populate pool", ex);
                        }
                    }
                });
                t.start();
                threads.add(t);
            }

            for (Thread t : threads) {
                try {
                    t.join(DEFAULT_TIMEOUT);
                } catch (InterruptedException ex) {
                    break;
                }
            }
        }


        if (maximum != null) {
            if (minimum != null && minimum > maximum) {
                maximum = minimum;
            }
            permits = new Semaphore(maximum, true); // does fairness matter?
        }
    }

    public RackApplication newApplication() throws RackInitializationException {
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

        return realFactory.newApplication();
    }

    public synchronized void finishedWithApplication(RackApplication app) {
        if (maximum != null && applicationPool.size() >= maximum) {
            return;
        }

        applicationPool.add(app);

        if (permits != null) {
            permits.release();
        }
    }

    public void destroy() {
        for (RackApplication app : applicationPool) {
            app.destroy();
        }
    }

    /** Used only by unit tests */
    public Queue<RackApplication> getApplicationPool() {
        return applicationPool;
    }

    private Integer getMaximum(ServletContext servletContext) {
        return getRangeValue(servletContext, "max", "maxActive");
    }

    private Integer getMinimum(ServletContext servletContext) {
        return getRangeValue(servletContext, "min", "minIdle");
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
