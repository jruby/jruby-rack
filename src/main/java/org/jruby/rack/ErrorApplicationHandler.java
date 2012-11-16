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

import org.jruby.Ruby;

/**
 * Handler that delegates to an error application with the given error.
 * 
 * @author kares
 */
public class ErrorApplicationHandler implements ErrorApplication {
   
    private Exception error;
    private final RackApplication errorApplication;

    public ErrorApplicationHandler(RackApplication errorApplication) {
        if (errorApplication == null) {
            throw new IllegalArgumentException("no error application given");
        }
        this.errorApplication = errorApplication;
    }

    public ErrorApplicationHandler(RackApplication errorApplication, Exception error) {
        this(errorApplication);
        setError(error);
    }

    public RackApplication getErrorApplication() {
        return errorApplication;
    }
    
    public Exception getError() {
        return error;
    }

    public void setError(Exception error) {
        this.error = error;
    }
    
    public RackResponse call(final RackEnvironment env) {
        env.setAttribute(RackEnvironment.EXCEPTION, getError());
        return getErrorApplication().call(env);
    }
    
    public void init() { getErrorApplication().init(); }
    
    public void destroy() { getErrorApplication().destroy(); }
    
    public Ruby getRuntime() { 
        return getErrorApplication().getRuntime();
    }
    
}
