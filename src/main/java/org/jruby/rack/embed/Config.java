/*
 * The MIT License
 *
 * Copyright (c) 2013-2014 Karol Bucek LTD.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package org.jruby.rack.embed;

import java.io.OutputStream;
import java.io.PrintStream;
import java.util.Map;

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

    public Config() {
        delegate = new DefaultRackConfig() {

            @Override
            public String getProperty(String key, String defaultValue) {
                String value = Config.this.resolveProperty(key);
                return value != null ? value : super.getProperty(key, defaultValue);
            }

            @Override
            public RackLogger defaultLogger() { return null; }

        };
    }

    @SuppressWarnings("unchecked")
    public void doInitialize(final Ruby runtime) {
        setOut( runtime.getOut() );
        setErr( runtime.getErr() );
        rubyENV = runtime.getENV();
    }


    protected String resolveProperty(String key) {
        String value = null;
        if ( rubyENV != null ) value = rubyENV.get(key);
        return value;
    }

    public final String getProperty(String key) {
        return delegate.getProperty(key);
    }

    public final String getProperty(String key, String defaultValue) {
        return delegate.getProperty(key, defaultValue);
    }

    public final Boolean getBooleanProperty(String key) {
        return delegate.getBooleanProperty(key);
    }

    public final Boolean getBooleanProperty(String key, Boolean defaultValue) {
        return delegate.getBooleanProperty(key, defaultValue);
    }

    public final Number getNumberProperty(String key) {
        return delegate.getNumberProperty(key);
    }

    public final Number getNumberProperty(String key, Number defaultValue) {
        return delegate.getNumberProperty(key, defaultValue);
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

    // runtime pooling in embedded ENVs not implemented :

    public Integer getRuntimeTimeoutSeconds() {
        //return delegate.getRuntimeTimeoutSeconds();
        throw new UnsupportedOperationException("getRuntimeTimeoutSeconds()");
    }

    public Integer getInitialRuntimes() {
        //return delegate.getInitialRuntimes();
        throw new UnsupportedOperationException("getInitialRuntimes()");
    }

    public Integer getMaximumRuntimes() {
        //return delegate.getMaximumRuntimes();
        throw new UnsupportedOperationException("getMaximumRuntimes()");
    }

    public String[] getRuntimeArguments() {
        //return delegate.getRuntimeArguments();
        throw new UnsupportedOperationException("getRuntimeArguments()");
    }

    public Integer getNumInitializerThreads() {
        //return delegate.getNumInitializerThreads();
        throw new UnsupportedOperationException("getNumInitializerThreads()");
    }

    public boolean isSerialInitialization() {
        //return delegate.isSerialInitialization();
        throw new UnsupportedOperationException("isSerialInitialization()");
    }

    public boolean isIgnoreEnvironment() {
        //return delegate.isIgnoreEnvironment();
        throw new UnsupportedOperationException("isIgnoreEnvironment()");
    }

    public Map<String, String> getRuntimeEnvironment() {
        throw new UnsupportedOperationException("getRuntimeEnvironment()");
    }

    // RackFilter aint's used with embed :

    public boolean isFilterAddsHtml() {
        throw new UnsupportedOperationException("isFilterAddsHtml()");
    }

    public boolean isFilterVerifiesResource() {
        throw new UnsupportedOperationException("isFilterVerifiesResource()");
    }

}
