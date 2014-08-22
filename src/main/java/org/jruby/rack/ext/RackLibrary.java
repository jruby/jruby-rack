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
import org.jruby.RubyModule;
import org.jruby.runtime.load.BasicLibraryService;
import org.jruby.runtime.load.Library;

/**
 * Sets up our (J)Ruby parts implemented in "native" Java.
 *
 * @author kares
 */
public class RackLibrary implements Library, BasicLibraryService {

    @SuppressWarnings("deprecation")
    public static void load(final Ruby runtime) {
        final RubyModule _JRuby = runtime.getOrCreateModule("JRuby");
        final RubyModule _JRuby_Rack = _JRuby.defineModuleUnder("Rack");

        final RubyClass _Object = runtime.getObject();

        // JRuby::Rack::Response
        final RubyClass _Response = _JRuby_Rack.defineClassUnder(
              "Response", _Object, Response.ALLOCATOR
        );
        _Response.defineAnnotatedMethods(Response.class);

        // JRuby::Rack::Input
        final RubyClass _Input = _JRuby_Rack.defineClassUnder(
              "Input", _Object, Input.ALLOCATOR
        );
        _Input.defineAnnotatedMethods(Input.class);
        _JRuby.setConstant("RackInput", _Input); // @deprecated backwards-compat

        // JRuby::Rack::Logger
        final RubyClass _Logger = _JRuby_Rack.defineClassUnder(
              "Logger", _Object, Logger.ALLOCATOR
        );
        _Logger.defineAnnotatedMethods(Logger.class);
        // JRuby::Rack::ServletLog
        final RubyClass _ServletLog = _JRuby_Rack.defineClassUnder(
              "ServletLog", _Object, Logger.ServletLog.ALLOCATOR
        );
        _ServletLog.defineAnnotatedMethods(Logger.ServletLog.class);

        final RubyModule _Rack = runtime.getOrCreateModule("Rack");
        final RubyModule _Rack_Handler = _Rack.defineModuleUnder("Handler");

        // Rack::Handler::Servlet
        final RubyClass _Servlet = _Rack_Handler.defineClassUnder(
              "Servlet", _Object, Servlet.ALLOCATOR);
        _Servlet.defineAnnotatedMethods(Servlet.class);
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
