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
package org.jruby.rack.ext;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Rack::Handler::Servlet
 *
 * @author kares
 */
@JRubyClass(name="Rack::Handler::Servlet")
public class Servlet extends RubyObject {

    static final ObjectAllocator ALLOCATOR = Servlet::new;

    protected Servlet(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    protected IRubyObject app;

    /**
     * @param app the rack app
     * @return nil
     */
    @JRubyMethod(required = 1)
    public IRubyObject initialize(final IRubyObject app) {
        if ( app.isNil() ) {
            throw getRuntime().newArgumentError(
                "rack app not found, make sure the rackup file path is correct");
        }
        this.app = app;
        return this;
    }


    @JRubyMethod(name = "get_app", alias = "app")
    public IRubyObject get_app() { return app; }

    /**
     * @param context the current ThreadContext
     * @param servlet_env the (servlet) environment
     * @return a response from the servlet
     */
    @JRubyMethod(required = 1)
    public IRubyObject call(final ThreadContext context, final IRubyObject servlet_env) {
        IRubyObject env = callMethod(context, "create_env", servlet_env);
        IRubyObject rack_response = app.callMethod(context, "call", env);
        // self.class.response.new @app.call( create_env(servlet_env) )
        IRubyObject responseClass = getMetaClass().callMethod(context, "response");
        return responseClass.callMethod(context, "new", rack_response);
    }

    /**
     * @param context the current ThreadContext
     * @param servlet_env the (servlet) environment
     * @return a new ENV hash
     */
    @JRubyMethod(required = 1)
    public RubyHash create_env(final ThreadContext context, final IRubyObject servlet_env) {
        // self.class.env.create(servlet_env).to_hash
        IRubyObject env = getMetaClass().callMethod(context, "env");
        return env.callMethod(context, "create", servlet_env).convertToHash();
    }

}