/*
 * Copyright (c) 2010 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.input.RackRewindableInput;
import org.jruby.rack.logging.RackLoggerFactory;
import org.jruby.rack.*;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Enumeration;
import java.util.Set;
import javax.servlet.RequestDispatcher;
import javax.servlet.Servlet;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;

import org.jruby.util.SafePropertyAccessor;
import static java.lang.System.out;

/**
 *
 * @author nicksieger
 */
public class ServletRackContext implements RackContext, ServletContext {
    private ServletContext context;
    private RackLogger logger;

    public ServletRackContext(ServletContext context) {
        this.context = context;
        this.logger = new RackLoggerFactory().getLogger(context);
        RackRewindableInput.setDefaultThreshold(
                SafePropertyAccessor.getInt("jruby.rack.request.size.threshold.bytes",
                RackRewindableInput.getDefaultThreshold()));
    }

    public String getInitParameter(String key) {
        return context.getInitParameter(key);
    }

    public void log(String message) {
        logger.log(message);
    }

    public void log(String message, Throwable ex) {
        logger.log(message, ex);
    }

    public String getRealPath(String path) {
        String realPath = context.getRealPath(path);
        if (realPath == null) { // some servers don't like getRealPath, e.g. w/o exploded war
            URL u = null;
            try {
                u = context.getResource(path);
            } catch (MalformedURLException ex) {}
            if (u != null) {
                realPath = u.getPath();
            }
        }
        return realPath;
    }

    public RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory) context.getAttribute(RackServletContextListener.FACTORY_KEY);
    }

    public ServletContext getContext(String path) {
        return context.getContext(path);
    }

    public String getContextPath() {
        return context.getContextPath();
    }

    public int getMajorVersion() {
        return context.getMajorVersion();
    }

    public int getMinorVersion() {
        return context.getMinorVersion();
    }

    public String getMimeType(String file) {
        return context.getMimeType(file);
    }

    public Set getResourcePaths(String path) {
        return context.getResourcePaths(path);
    }

    public URL getResource(String path) throws MalformedURLException {
        return context.getResource(path);
    }

    public InputStream getResourceAsStream(String path) {
        return context.getResourceAsStream(path);
    }

    public RequestDispatcher getRequestDispatcher(String path) {
        return context.getRequestDispatcher(path);
    }

    public RequestDispatcher getNamedDispatcher(String name) {
        return context.getNamedDispatcher(name);
    }

    @Deprecated
    public Servlet getServlet(String name) throws ServletException {
        return context.getServlet(name);
    }

    @Deprecated
    public Enumeration getServlets() {
        return context.getServlets();
    }

    @Deprecated
    public Enumeration getServletNames() {
        return context.getServletNames();
    }

    @Deprecated
    public void log(Exception ex, String msg) {
        context.log(ex, msg);
    }

    public String getServerInfo() {
        return context.getServerInfo();
    }

    public Enumeration getInitParameterNames() {
        return context.getInitParameterNames();
    }

    public Object getAttribute(String key) {
        return context.getAttribute(key);
    }

    public Enumeration getAttributeNames() {
        return context.getAttributeNames();
    }

    public void setAttribute(String key, Object val) {
        context.setAttribute(key, val);
    }

    public void removeAttribute(String key) {
        context.removeAttribute(key);
    }

    public String getServletContextName() {
        return context.getServletContextName();
    }
}
