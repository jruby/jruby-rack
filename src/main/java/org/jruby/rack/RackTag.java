/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.jsp.JspException;
import javax.servlet.jsp.tagext.TagSupport;

import org.jruby.rack.servlet.ServletRackEnvironment;

@SuppressWarnings("serial")
public class RackTag extends TagSupport {
    private String path;
    private String params;

    public void setPath(String path) {
        this.path = path;
    }

    public void setParams(String params) {
        this.params = params;
    }

    @Override
    public int doEndTag() throws JspException {
        try {
            RackApplicationFactory factory = (RackApplicationFactory)
                    pageContext.getServletContext().getAttribute(RackApplicationFactory.FACTORY);
            RackContext context = (RackContext)
                    pageContext.getServletContext().getAttribute(RackApplicationFactory.RACK_CONTEXT);
            RackApplication app = factory.getApplication();
            try {
                final HttpServletRequest request =
                        new HttpServletRequestWrapper((HttpServletRequest) pageContext.getRequest()) {
                    @Override public String getMethod() { return "GET"; }
                    @Override public String getRequestURI() { return path; }
                    @Override public String getPathInfo() { return path; }
                    @Override public String getQueryString() { return params; }
                    @Override public String getServletPath() { return ""; }
                };
                RackResponse result = app.call(new ServletRackEnvironment(request, (HttpServletResponse) pageContext.getResponse(), context));
                pageContext.getOut().write(result.getBody());
            } finally {
              factory.finishedWithApplication(app);
            }
        } catch (Exception e) {
            throw new JspException(e);
        }
        return EVAL_PAGE;
    }
}
