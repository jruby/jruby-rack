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
import org.jruby.runtime.load.Library;

/**
 * Sets up our (J)Ruby parts implemented in Java.
 *
 * @author kares
 */
public class RackLibrary implements Library, BasicLibraryService {

    public static void load(final Ruby runtime) {
        final RubyModule _JRuby = runtime.getOrCreateModule("JRuby");
        final RubyModule _JRuby_Rack = _JRuby.defineModuleUnder("Rack");

        final RubyClass _Object = runtime.getObject();
        // JRuby::Rack::Response
        final RubyClass _Response = _JRuby_Rack.defineClassUnder(
              "Response", _Object, Response.ALLOCATOR
        );
        _Response.defineAnnotatedMethods(Response.class);

        final RubyModule _Rack = runtime.getOrCreateModule("Rack");
        final RubyModule _Rack_Handler = _Rack.defineModuleUnder("Handler");

        // Rack::Handler::Servlet
        //RubyClass servlet = rackHandler.defineClassUnder("Servlet", runtime.getObject(), Servlet.ALLOCATOR);
        //servlet.defineAnnotatedMethods(Servlet.class);
    }

    @Override
    public boolean basicLoad(final Ruby runtime) {
        load(runtime);
        return true;
    }

    @Override
    public void load(Ruby runtime, boolean wrap) {
        load(runtime);
    }

}
