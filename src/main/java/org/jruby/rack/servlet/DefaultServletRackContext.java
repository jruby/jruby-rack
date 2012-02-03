/*
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

package org.jruby.rack.servlet;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackLogger;

import javax.servlet.RequestDispatcher;
import javax.servlet.Servlet;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Enumeration;
import java.util.Set;

/**
 *
 * @author nicksieger
 */
public class DefaultServletRackContext implements ServletRackContext {
    
    private RackConfig config;
    private ServletContext context;
    private RackLogger logger;

    public DefaultServletRackContext(ServletRackConfig config) {
        this.config  = config;
        this.context = config.getServletContext();
        this.logger  = config.getLogger();
    }

    public String getInitParameter(String key) {
        return config.getProperty(key);
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
            try {
                URL url = context.getResource(path);
                if (url != null) {
                    String urlPath = url.getPath();
                    // still might end up as an URL with path "file:/home"
                    if (urlPath.startsWith("file:")) {
                        // handles "file:/home" and "file:///home" as well
                        realPath = new URL(urlPath).getPath(); // "/home"
                    }
                    else {
                        realPath = urlPath;
                    }
                }
            }
            catch (MalformedURLException e) { /* ignored */ }
        }
        return realPath;
    }

    public RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory) context.getAttribute(RackApplicationFactory.FACTORY);
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
        logger.log(msg, ex);
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

    public RackConfig getConfig() {
        return config;
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
