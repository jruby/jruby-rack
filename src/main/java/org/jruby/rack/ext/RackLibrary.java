/*
 * The MIT License
 *
 * Copyright 2013 kares.
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
import org.jruby.RubyModule;
import org.jruby.runtime.load.BasicLibraryService;

/**
 * Sets up our (J)Ruby parts implemented in Java.
 * 
 * @author kares
 */
public class RackLibrary implements BasicLibraryService {

    public boolean basicLoad(final Ruby runtime) {
        final RubyModule jruby = runtime.getOrCreateModule("JRuby");
        final RubyModule jrubyRack = jruby.defineModuleUnder("Rack");

        // JRuby::Rack::Response
        RubyClass response = jrubyRack.defineClassUnder("Response", runtime.getObject(), Response.ALLOCATOR);
        response.defineAnnotatedMethods(Response.class);

        final RubyModule rack = runtime.getOrCreateModule("Rack");
        final RubyModule rackHandler = rack.defineModuleUnder("Handler");

        // Rack::Handler::Servlet
        //RubyClass servlet = rackHandler.defineClassUnder("Servlet", runtime.getObject(), Servlet.ALLOCATOR);
        //servlet.defineAnnotatedMethods(Servlet.class);

        return true;
    }

}
