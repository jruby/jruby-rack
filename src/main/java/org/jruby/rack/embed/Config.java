/*
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */
package org.jruby.rack.embed;

import java.io.OutputStream;
import java.io.PrintStream;
import java.util.Map;

import org.jruby.CompatVersion;
import org.jruby.Ruby;
import org.jruby.rack.DefaultRackConfig;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackLogger;

/**
 * A rack config for an embedded environment.
 * 
 * @author kares
 */
public class Config implements RackConfig {
    
    private final DefaultRackConfig delegate;
    
    private RackLogger logger;
    private Map<String, String> rubyENV;
    private CompatVersion compatVersion;

    public Config() {
        delegate = new DefaultRackConfig() {
            
            @Override
            public String getProperty(String key, String defaultValue) {
                String value = Config.this.getProperty(key, null);
                if (value != null) return value;
                return super.getProperty(key, defaultValue);
            }
            
        };
    }
    
    public String getProperty(String key) {
        return getProperty(key, null);
    }

    public String getProperty(String key, String defaultValue) {
        if (rubyENV != null) {
            String value = rubyENV.get(key);
            if (value != null) return value;
        }
        return defaultValue; // delegated in custom DefaultRackConfig#getProperty
    }

    public boolean getBooleanProperty(String key) {
        return getBooleanProperty(key, false);
    }

    public boolean getBooleanProperty(String key, boolean defaultValue) {
        return DefaultRackConfig.toBoolean(getProperty(key), defaultValue);
    }
    
    public CompatVersion getCompatVersion() {
        return compatVersion;
    }
    
    public RackLogger getLogger() {
        if (logger == null) {
            logger = delegate.getLogger();
        }
        return logger;
    }

    public void setLogger(RackLogger logger) {
        this.logger = logger;
    }
    
    public PrintStream getOut() {
        return delegate.getOut();
    }
    
    public void setOut(OutputStream out) {
        delegate.setOut(out);
    }
    
    public PrintStream getErr() {
        return delegate.getErr();
    }
    
    public void setErr(OutputStream err) {
        delegate.setErr(err);
    }
    
    public boolean isRewindable() {
        return delegate.isRewindable();
    }

    public Integer getInitialMemoryBufferSize() {
        return delegate.getInitialMemoryBufferSize();
    }

    public Integer getMaximumMemoryBufferSize() {
        return delegate.getMaximumMemoryBufferSize();
    }
    
    public String getRackup() {
        return delegate.getRackup();
    }

    public String getRackupPath() {
        return delegate.getRackupPath();
    }

    // TODO revisit these - do they make sense ?!
    
    public Integer getRuntimeTimeoutSeconds() {
        return delegate.getRuntimeTimeoutSeconds();
        //throw new UnsupportedOperationException("getRuntimeTimeoutSeconds()");
    }

    public Integer getInitialRuntimes() {
        return delegate.getInitialRuntimes();
        //throw new UnsupportedOperationException("getInitialRuntimes()");
    }

    public Integer getMaximumRuntimes() {
        return delegate.getMaximumRuntimes();
        //throw new UnsupportedOperationException("getMaximumRuntimes()");
    }

    public String[] getRuntimeArguments() {
        return delegate.getRuntimeArguments();
        //throw new UnsupportedOperationException("getRuntimeArguments()");
    }
    
    public Integer getNumInitializerThreads() {
        return delegate.getNumInitializerThreads();
        //throw new UnsupportedOperationException("getNumInitializerThreads()");
    }

    public boolean isSerialInitialization() {
        return delegate.isSerialInitialization();
        //throw new UnsupportedOperationException("isSerialInitialization()");
    }

    public boolean isIgnoreEnvironment() {
        return delegate.isIgnoreEnvironment();
        //throw new UnsupportedOperationException("isIgnoreEnvironment()");
    }
    
    public boolean isFilterAddsHtml() {
        throw new UnsupportedOperationException("isFilterAddsHtml()");
    }

    public boolean isFilterVerifiesResource() {
        throw new UnsupportedOperationException("isFilterVerifiesResource()");
    }

    public String getJmsConnectionFactory() {
        throw new UnsupportedOperationException("getJmsConnectionFactory()");
    }

    public String getJmsJndiProperties() {
        throw new UnsupportedOperationException("getJmsJndiProperties()");
    }
    
}
