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
    private RackApplicationFactory rackFactory;
    private String loader;

    public RackServlet() {
        this(new DefaultRackApplicationFactory());
    }

    public RackServlet(RackApplicationFactory rackFactory) {
        this.rackFactory = rackFactory;
    }

    @Override
    public void init() throws ServletException {
        this.loader = getServletContext().getInitParameter("rackup");
    }
    
    @Override
    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
        process((HttpServletRequest) request, (HttpServletResponse) response);
    }

    public void process(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {
        RackApplication app = null;
        try {
            app = rackFactory.newApplication(loader);
            RackResult result = app.call(request);
            result.writeStatus(response);
            result.writeHeaders(response);
            result.writeBody(response);
        } catch (Exception re) {
            throw new ServletException("Error processing request", re);
        } finally {
            if (app != null) {
                rackFactory.finishedWithApplication(app);
            }
        }
    }
}
