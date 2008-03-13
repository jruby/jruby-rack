package org.jruby.rack;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletRequestWrapper;
import javax.servlet.jsp.tagext.TagSupport;
import javax.servlet.jsp.JspException;

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
                pageContext.getServletContext().getAttribute(RackServletContextListener.FACTORY_KEY);
            RackApplication app = factory.getApplication();
            try {
                RackResponse result = app.call(new HttpServletRequestWrapper((HttpServletRequest) pageContext.getRequest()) {
                    public String getRequestURI() { return path; }
                    public String getQueryString() { return params; }
                    public String getMethod() { return "GET"; }
                });
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
