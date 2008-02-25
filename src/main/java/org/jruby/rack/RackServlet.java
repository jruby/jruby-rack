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

import java.io.IOException;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 *
 * @author nicksieger
 */
public class RackServlet extends HttpServlet {
    static final String EXCEPTION = "rack.exception";

    private ServletContext servletContext;

    public RackServlet() {
    }

    @Override
    public void init(ServletConfig config) {
        this.servletContext = config.getServletContext();
    }
    
    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        process((HttpServletRequest) request, (HttpServletResponse) response);
    }

    public void process(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        final RackApplicationFactory rackFactory = getRackFactory();
        RackApplication app = null;
        try {
            app = rackFactory.getApplication();
            callApplication(app, request, response);
        } catch (Exception re) {
            handleException(re, rackFactory, request, response);
        } finally {
            if (app != null) {
                rackFactory.finishedWithApplication(app);
            }
        }
    }

    private void callApplication(RackApplication app, HttpServletRequest request,
            HttpServletResponse response) {
        RackResult result = app.call(request);
        result.writeStatus(response);
        result.writeHeaders(response);
        result.writeBody(response);
    }

    private RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory)
            servletContext.getAttribute(RackServletContextListener.FACTORY_KEY);
    }

    private void handleException(Exception re, RackApplicationFactory rackFactory,
            HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        if (response.isCommitted()) {
            servletContext.log("Couldn't handle error: response committed", re);
            return;
        }
        response.reset();

        try {
            RackApplication errorApp = rackFactory.getErrorApplication();
            request.setAttribute(EXCEPTION, re);
            callApplication(errorApp, request, response);
        } catch (Exception e) {
            servletContext.log("Couldn't handle error", e);
            response.sendError(500);
        }
    }
}
