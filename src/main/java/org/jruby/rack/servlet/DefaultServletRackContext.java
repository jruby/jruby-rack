/*
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.servlet;

import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackLogger;

import javax.servlet.Filter;
import javax.servlet.RequestDispatcher;
import javax.servlet.Servlet;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
// 3.0
import javax.servlet.FilterRegistration;
import javax.servlet.ServletRegistration;
import javax.servlet.SessionCookieConfig;
import javax.servlet.SessionTrackingMode;
import javax.servlet.descriptor.JspConfigDescriptor;

import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Enumeration;
import java.util.EventListener;
import java.util.Map;
import java.util.Set;

/**
 *
 * @author nicksieger
 */
public class DefaultServletRackContext implements ServletRackContext, RackLogger.DelegatingLogger {

    private final RackConfig config;
    private final ServletContext context;
    private final RackLogger logger;

    public DefaultServletRackContext(ServletRackConfig config) {
        this.config  = config;
        this.context = config.getServletContext();
        this.logger  = config.getLogger();
    }

    // Helpers

    ServletContext getRealContext() { return getContext(); }

    public static ServletContext getRealContext(final ServletContext context) {
        if ( context instanceof DefaultServletRackContext ) {
            return ((DefaultServletRackContext) context).getRealContext();
        }
        return context;
    }

    @Override
    public RackApplicationFactory getRackFactory() {
        return (RackApplicationFactory) getAttribute(RackApplicationFactory.FACTORY);
    }

    @Override
    public RackConfig getConfig() {
        return config;
    }

    @Override
    public String getInitParameter(final String key) {
        return config.getProperty(key);
    }

    @Override
    public String getRealPath(final String path) {
        String realPath = context.getRealPath(path);
        if (realPath == null) { // some servers don't like getRealPath, e.g. w/o exploded war
            try {
                final URL url = context.getResource(path);
                if (url != null) {
                    final String urlPath = url.getPath();
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

    public ServletContext getContext() {
        return context;
    }

    @Override
    public ServletContext getContext(String path) {
        return context.getContext(path);
    }

    @Override
    public String getContextPath() {
        return context.getContextPath();
    }

    @Override
    public int getMajorVersion() {
        return context.getMajorVersion();
    }

    @Override
    public int getMinorVersion() {
        return context.getMinorVersion();
    }

    @Override
    public String getMimeType(String file) {
        return context.getMimeType(file);
    }

    @Override
    public Set<String> getResourcePaths(String path) {
        return context.getResourcePaths(path);
    }

    @Override
    public URL getResource(String path) throws MalformedURLException {
        return context.getResource(path);
    }

    @Override
    public InputStream getResourceAsStream(String path) {
        return context.getResourceAsStream(path);
    }

    @Override
    public RequestDispatcher getRequestDispatcher(String path) {
        return context.getRequestDispatcher(path);
    }

    @Override
    public RequestDispatcher getNamedDispatcher(String name) {
        return context.getNamedDispatcher(name);
    }

    @Override @Deprecated
    public Servlet getServlet(String name) throws ServletException {
        return context.getServlet(name);
    }

    @Override @Deprecated
    public Enumeration<Servlet> getServlets() {
        return context.getServlets();
    }

    @Override @Deprecated
    public Enumeration<String> getServletNames() {
        return context.getServletNames();
    }

    @Override
    public String getServerInfo() {
        return context.getServerInfo();
    }

    @Override
    public Enumeration<String> getInitParameterNames() {
        return context.getInitParameterNames();
    }

    @Override
    public Object getAttribute(String key) {
        return context.getAttribute(key);
    }

    @Override
    public Enumeration<String> getAttributeNames() {
        return context.getAttributeNames();
    }

    @Override
    public void setAttribute(String key, Object val) {
        context.setAttribute(key, val);
    }

    @Override
    public void removeAttribute(String key) {
        context.removeAttribute(key);
    }

    @Override
    public String getServletContextName() {
        return context.getServletContextName();
    }

    @Override @Deprecated
    public void log(Exception e, String msg) {
        logger.log(msg, e);
    }

    // RackLogger

    @Override
    public boolean isEnabled(Level level) {
        return logger.isEnabled(level);
    }

    @Override
    public void log(CharSequence message) {
        logger.log(message);
    }

    @Override
    public void log(CharSequence message, Throwable e) {
        logger.log(message, e);
    }

    @Override
    public void log(Level level, CharSequence message) {
        logger.log(level, message);
    }

    @Override
    public void log(Level level, CharSequence message, Throwable e) {
        logger.log(level, message, e);
    }

    @Override
    public RackLogger unwrapLogger() {
        return logger;
    }

    @Override
    public int getEffectiveMajorVersion() throws UnsupportedOperationException {
        return context.getEffectiveMajorVersion();
    }

    @Override
    public int getEffectiveMinorVersion() throws UnsupportedOperationException {
        return context.getEffectiveMinorVersion();
    }

    @Override
    public ClassLoader getClassLoader() {
        return context.getClassLoader();
    }

    @Override
    public boolean setInitParameter(String name, String value) {
        return context.setInitParameter(name, value);
    }

    @Override
    public void declareRoles(String... roleNames) {
        context.declareRoles(roleNames);
    }

    @Override
    public String getVirtualServerName() {
        return context.getVirtualServerName();
    }

    @Override
    public int getSessionTimeout() {
        return context.getSessionTimeout();
    }

    @Override
    public void setSessionTimeout(int sessionTimeout) {
        context.setSessionTimeout(sessionTimeout);
    }

    @Override
    public String getRequestCharacterEncoding() {
        return context.getRequestCharacterEncoding();
    }

    @Override
    public void setRequestCharacterEncoding(String encoding) {
        context.setRequestCharacterEncoding(encoding);
    }

    @Override
    public String getResponseCharacterEncoding() {
        return context.getResponseCharacterEncoding();
    }

    @Override
    public void setResponseCharacterEncoding(String encoding) {
        context.setResponseCharacterEncoding(encoding);
    }

    @Override
    public <T extends Servlet> T createServlet(Class<T> type) throws ServletException {
        return context.createServlet(type);
    }

    @Override
    public ServletRegistration.Dynamic addServlet(String servletName, String className) throws IllegalArgumentException, IllegalStateException {
        return context.addServlet(servletName, className);
    }

    @Override
    public ServletRegistration.Dynamic addServlet(String servletName, Servlet servlet) throws IllegalArgumentException, IllegalStateException {
        return context.addServlet(servletName, servlet);
    }

    @Override
    public ServletRegistration.Dynamic addServlet(String servletName, Class<? extends Servlet> servletClass) throws IllegalArgumentException, IllegalStateException {
        return context.addServlet(servletName, servletClass);
    }

    @Override
    public ServletRegistration.Dynamic addJspFile(String servletName, String jspFile) {
        return context.addJspFile(servletName, jspFile);
    }

    @Override
    public ServletRegistration getServletRegistration(String servletName) {
        return context.getServletRegistration(servletName);
    }

    @Override
    public Map<String, ? extends ServletRegistration> getServletRegistrations() {
        return context.getServletRegistrations();
    }

    @Override
    public <T extends Filter> T createFilter(Class<T> type) throws ServletException {
        return context.createFilter(type);
    }

    @Override
    public FilterRegistration.Dynamic addFilter(String filterName, String className) throws IllegalArgumentException, IllegalStateException {
        return context.addFilter(filterName, className);
    }

    @Override
    public FilterRegistration.Dynamic addFilter(String filterName, Filter filter) throws IllegalArgumentException, IllegalStateException {
        return context.addFilter(filterName, filter);
    }

    @Override
    public FilterRegistration.Dynamic addFilter(String filterName, Class<? extends Filter> filterClass) throws IllegalArgumentException, IllegalStateException {
        return context.addFilter(filterName, filterClass);
    }

    @Override
    public FilterRegistration getFilterRegistration(String filterName) {
        return context.getFilterRegistration(filterName);
    }

    @Override
    public Map<String, ? extends FilterRegistration> getFilterRegistrations() {
        return context.getFilterRegistrations();
    }

    @Override
    public void addListener(Class<? extends EventListener> listenerClass) {
        context.addListener(listenerClass);
    }

    @Override
    public void addListener(String className) {
        context.addListener(className);
    }

    @Override
    public <T extends EventListener> void addListener(T listener) {
        context.addListener(listener);
    }

    @Override
    public <T extends EventListener> T createListener(Class<T> listenerClass) throws ServletException {
        return context.createListener(listenerClass);
    }

    @Override
    public SessionCookieConfig getSessionCookieConfig() {
        return context.getSessionCookieConfig();
    }

    @Override
    public void setSessionTrackingModes(Set<SessionTrackingMode> sessionTrackingModes) {
        context.setSessionTrackingModes(sessionTrackingModes);
    }

    @Override
    public Set<SessionTrackingMode> getDefaultSessionTrackingModes() {
        return context.getDefaultSessionTrackingModes();
    }

    @Override
    public Set<SessionTrackingMode> getEffectiveSessionTrackingModes() {
        return context.getEffectiveSessionTrackingModes();
    }

    @Override
    public JspConfigDescriptor getJspConfigDescriptor() {
        return context.getJspConfigDescriptor();
    }

}
