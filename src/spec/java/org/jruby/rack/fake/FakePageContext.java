package org.jruby.rack.fake;

import java.io.IOException;
import java.util.Enumeration;
import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import javax.servlet.jsp.PageContext;

/**
 * Currently only used as a mock for testing.
 */
public class FakePageContext extends PageContext {
    private ServletContext context;
    private ServletRequest request;
    private ServletResponse response;
    private JspWriter out;
    
    public FakePageContext(ServletContext context, HttpServletRequest request, HttpServletResponse response, JspWriter out) {
        this.context = context;
        this.request = request;
        this.response = response;
        this.out = out;
    }
    @Override
    public Object findAttribute(String arg0) {
        throw new UnsupportedOperationException("Not supported yet. findAttribute");
    }

    @Override
    public void forward(String arg0) throws ServletException, IOException {
        throw new UnsupportedOperationException("Not supported yet. forward");
    }

    @Override
    public Object getAttribute(String arg0) {
        throw new UnsupportedOperationException("Not supported yet. getAttribute");
    }

    @Override
    public Object getAttribute(String arg0, int arg1) {
        throw new UnsupportedOperationException("Not supported yet. getAttribute2");
    }

    @Override
    public Enumeration getAttributeNamesInScope(int arg0) {
        throw new UnsupportedOperationException("Not supported yet. getAttributeNamesInScope");
    }

    @Override
    public int getAttributesScope(String arg0) {
        throw new UnsupportedOperationException("Not supported yet. getAttributesScope");
    }

    @Override
    public Exception getException() {
        throw new UnsupportedOperationException("Not supported yet. getException");
    }

    @Override
    public JspWriter getOut() {
        return out;
    }

    @Override
    public Object getPage() {
        throw new UnsupportedOperationException("Not supported yet. getPage");
    }

    @Override
    public ServletRequest getRequest() {
        return request;
    }

    @Override
    public ServletResponse getResponse() {
        return response;
    }

    @Override
    public ServletConfig getServletConfig() {
        throw new UnsupportedOperationException("Not supported yet. getServletConfig");
    }

    @Override
    public ServletContext getServletContext() {
        return context;
    }

    @Override
    public HttpSession getSession() {
        throw new UnsupportedOperationException("Not supported yet. getSession");
    }

    @Override
    public void handlePageException(Exception arg0) throws ServletException, IOException {
        throw new UnsupportedOperationException("Not supported yet. handlePageException");
    }

    @Override
    public void handlePageException(Throwable arg0) throws ServletException, IOException {
        throw new UnsupportedOperationException("Not supported yet. handlePageException");
    }

    @Override
    public void include(String arg0) throws ServletException, IOException {
        throw new UnsupportedOperationException("Not supported yet. include");
    }

    @Override
    public void initialize(Servlet arg0, ServletRequest arg1, ServletResponse arg2, String arg3, boolean arg4, int arg5, boolean arg6) throws IOException, IllegalStateException, IllegalArgumentException {
        throw new UnsupportedOperationException("Not supported yet. initialize");
    }

    @Override
    public void release() {
        throw new UnsupportedOperationException("Not supported yet. release");
    }

    @Override
    public void removeAttribute(String arg0) {
        throw new UnsupportedOperationException("Not supported yet. removeAttribute");
    }

    @Override
    public void removeAttribute(String arg0, int arg1) {
        throw new UnsupportedOperationException("Not supported yet. removeAttribute");
    }

    @Override
    public void setAttribute(String arg0, Object arg1) {
        throw new UnsupportedOperationException("Not supported yet. setAttribute");
    }

    @Override
    public void setAttribute(String arg0, Object arg1, int arg2) {
        throw new UnsupportedOperationException("Not supported yet setAttribute");
    }
	
}