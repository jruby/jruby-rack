/*
 * The MIT License
 *
 * Copyright 2012 kares.
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
package org.jruby.rack;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Collections;
import java.util.Map;

import org.jruby.Ruby;

/**
 * Default error application if the Rack error application can not be setup or
 * "jruby.rack.error" handling is turned off (set to false).
 * 
 * By default, this application re-throws the error wrapped into a 
 * {@link RackException} on {@link #call(org.jruby.rack.RackEnvironment)}.
 * 
 * @author kares
 */
public class DefaultErrorApplication extends DefaultRackApplication
    implements ErrorApplication {
    
    protected final RackContext context;
    
    public DefaultErrorApplication() {
        this(null);
    }
    
    DefaultErrorApplication(RackContext context) {
        this.context = context;
    }
    
    @Override
    public Ruby getRuntime() {
        throw new UnsupportedOperationException("getRuntime() not supported");
    }
    
    public void init() {
        // NOOP
    }
    
    public void destroy() { 
        // NOOP
    }
    
    @Override
    public RackResponse call(RackEnvironment env) throws RackException {
        return new Response(env); // backwards compatibility
    }
    
    static Exception getException(RackEnvironment env) {
        return (Exception) env.getAttribute(RackEnvironment.EXCEPTION);
    }
    
    /**
     * Backwards compatibility error response.
     * Prints the error stack trace and responds with HTTP 500 without headers.
     */
    private class Response implements RackResponse {

        private int status = 500;
        @SuppressWarnings("rawtypes")
        private Map headers = Collections.EMPTY_MAP;
        private String body;
        
        protected final RackEnvironment env;
        
        public Response(RackEnvironment env) { this.env = env; }
        
        public int getStatus() {
            return status;
        }

        @SuppressWarnings("unused")
        public void setStatus(int status) {
            this.status = status;
        }
        
        @SuppressWarnings("rawtypes")
        public Map getHeaders() {
            return headers;
        }

        @SuppressWarnings("unused")
        public void setHeaders(@SuppressWarnings("rawtypes") Map headers) {
            this.headers = headers == null ? Collections.EMPTY_MAP : headers;
        }
        
        public String getBody() {
            if ( body == null ) {
                try {
                    body = buildErrorBody();
                }
                catch (Exception e) {
                    log(RackLogger.INFO, "failed building error body", e);
                    body = getError() == null ? "" : getError().toString();
                }
            }
            return body;
        }

        @SuppressWarnings("unused")
        public void setBody(String body) {
            this.body = body;
        }
        
        public Exception getError() {
            return getException(env);
        }
        
        protected String buildErrorBody() {
            StringWriter stringWriter = new StringWriter(1024);
            if ( getError() != null ) {
                PrintWriter printWriter = new PrintWriter(stringWriter);
                getError().printStackTrace(printWriter);
                printWriter.println();
                printWriter.close();
            }
            return stringWriter.toString();
        }
        
        public void respond(RackResponseEnvironment response) {
            try {
                response.defaultRespond(this);
            }
            catch (IOException e) {
                log(RackLogger.WARN, "could not write response body", e);
            }
        }
        
        private void log(String level, String message, Throwable e) {
            if ( context != null ) context.log(level, message, e);
        }
        
    }
    
}
