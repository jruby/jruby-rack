
package org.jruby.rack;

import java.util.Collections;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.servlet.ServletContext;
import javax.servlet.http.HttpSession;
import javax.servlet.http.HttpSessionBindingEvent;
import javax.servlet.http.HttpSessionBindingListener;
import javax.servlet.http.HttpSessionContext;

/**
 * Mock implementation of {@link javax.servlet.http.HttpSession}.
 * Inspired by SpringFX's MockHttpSession implementation ...
 */
public class MockHttpSession implements HttpSession {

    public static final String SESSION_COOKIE_NAME = "JSESSION";
    private static int nextId = 1;

    private final String id;

    private final long creationTime = System.currentTimeMillis();

    private int maxInactiveInterval;

    private long lastAccessedTime = System.currentTimeMillis();

    private final ServletContext servletContext;

    private final Map<String, Object> attributes = new LinkedHashMap<String, Object>();

    private boolean invalid = false;

    private boolean isNew = true;

    public MockHttpSession() {
        this(null);
    }
    
    public MockHttpSession(ServletContext servletContext) {
        this(servletContext, null);
    }
    
    public MockHttpSession(ServletContext servletContext, String id) {
        this.servletContext = servletContext;
        this.id = (id != null ? id : Integer.toString(nextId++));
    }
    
    public long getCreationTime() throws IllegalStateException {
        checkInvalid();
        return this.creationTime;
    }

    public String getId() throws IllegalStateException {
        checkInvalid();
        return this.id;
    }

    public long getLastAccessedTime() throws IllegalStateException {
        checkInvalid();
        return this.lastAccessedTime;
    }

    public ServletContext getServletContext() {
        return this.servletContext;
    }

    public void setMaxInactiveInterval(int interval) {
        this.maxInactiveInterval = interval;
    }

    public int getMaxInactiveInterval() {
        return this.maxInactiveInterval;
    }

    public HttpSessionContext getSessionContext() {
        throw new UnsupportedOperationException("getSessionContext");
    }

    public Object getAttribute(String name) throws IllegalStateException {
        checkInvalid();
        return this.attributes.get(name);
    }

    public Object getValue(String name) throws IllegalStateException {
        checkInvalid();
        return getAttribute(name);
    }

    public Enumeration<String> getAttributeNames() throws IllegalStateException {
        checkInvalid();
        return Collections.enumeration(this.attributes.keySet());
    }

    public String[] getValueNames() throws IllegalStateException {
        checkInvalid();
        return this.attributes.keySet().toArray(new String[this.attributes.size()]);
    }

    public void setAttribute(String name, Object value) throws IllegalStateException {
        checkInvalid();
        if (value != null) {
            this.attributes.put(name, value);
            if (value instanceof HttpSessionBindingListener) {
                ((HttpSessionBindingListener) value).valueBound(new HttpSessionBindingEvent(this, name, value));
            }
        }
        else {
            removeAttribute(name);
        }
    }

    public void putValue(String name, Object value) throws IllegalStateException {
        checkInvalid();
        setAttribute(name, value);
    }

    public void removeAttribute(String name) throws IllegalStateException {
        checkInvalid();
        Object value = this.attributes.remove(name);
        if (value instanceof HttpSessionBindingListener) {
            ((HttpSessionBindingListener) value).valueUnbound(new HttpSessionBindingEvent(this, name, value));
        }
    }

    public void removeValue(String name) throws IllegalStateException {
        checkInvalid();
        removeAttribute(name);
    }

    public void invalidate() throws IllegalStateException {
        checkInvalid();
        this.invalid = true;
        clearAttributes();
    }
    
    public boolean isNew() throws IllegalStateException {
        checkInvalid();
        return this.isNew;
    }

    void access() {
        this.lastAccessedTime = System.currentTimeMillis();
        this.isNew = false;
    }
    
    boolean isInvalid() {
        return this.invalid;
    }

    void setNew(boolean value) {
        this.isNew = value;
    }
    
    void clearAttributes() {
        for (Iterator<Map.Entry<String, Object>> it = this.attributes.entrySet().iterator(); it.hasNext();) {
            Map.Entry<String, Object> entry = it.next();
            String name = entry.getKey();
            Object value = entry.getValue();
            it.remove();
            if (value instanceof HttpSessionBindingListener) {
                ((HttpSessionBindingListener) value).valueUnbound(new HttpSessionBindingEvent(this, name, value));
            }
        }
    }

    private void checkInvalid() {
        if (this.invalid) throw new IllegalStateException("Session already invalidated");
    }
    
}
