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
 *
 * @author nicksieger
 */
public class PoolingRackApplicationFactory implements RackApplicationFactory {
    static final int DEFAULT_TIMEOUT = 30;
    private RackApplicationFactory realFactory;
    private Queue<RackApplication> applicationPool = new LinkedList<RackApplication>();
    private Integer minimum, maximum;
    private long timeout = DEFAULT_TIMEOUT;
    private Semaphore permits;
    
    public PoolingRackApplicationFactory(RackApplicationFactory factory) {
        realFactory = factory;
    }

    public void init(ServletContext servletContext) throws ServletException {
        realFactory.init(servletContext);
        timeout = DEFAULT_TIMEOUT;
        Integer specifiedTimeout = getPositiveInteger(servletContext, "jruby.runtime.timeout.sec");
        if (specifiedTimeout != null) {
            timeout = specifiedTimeout.longValue();
        }
        minimum = getMinimum(servletContext);
        maximum = getMaximum(servletContext);
        if (minimum != null) {
            for (int i = 0; i < minimum; i++) {
                try {
                    applicationPool.add(realFactory.newApplication());
                } catch (RackInitializationException ex) {
                    throw new ServletException("unable to pre-populate pool", ex);
                }
            }
        }
        if (maximum != null) {
            permits = new Semaphore(maximum);
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
        Integer v = getPositiveInteger(servletContext, "jruby.max.runtimes");
        if (v == null) {
            v = getPositiveInteger(servletContext, "jruby.pool.maxActive");
        }
        return v;
    }

    private Integer getMinimum(ServletContext servletContext) {
        Integer v = getPositiveInteger(servletContext, "jruby.min.runtimes");
        if (v == null) {
            v = getPositiveInteger(servletContext, "jruby.pool.minIdle");
        }
        return v;
    }

    private Integer getPositiveInteger(ServletContext servletContext, String string) {
        try {
            String v = servletContext.getInitParameter(string);
            if (v != null) {
                int i = Integer.parseInt(v);
                if (i > 0) {
                    return new Integer(i);
                }
            }
        } catch (Exception e) {
        }
        return null;
    }
}
