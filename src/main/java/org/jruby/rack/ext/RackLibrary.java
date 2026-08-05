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
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.load.BasicLibraryService;
import org.jruby.runtime.load.Library;

import static org.jruby.rack.util.JRubyCompat.*;

/**
 * Sets up our (J)Ruby parts implemented in "native" Java.
 *
 * @author kares
 */
public class RackLibrary implements Library, BasicLibraryService {

    public static void load(final Ruby runtime) {
        ThreadContext context = runtime.getCurrentContext();
        final RubyModule _JRuby = defineModule(context, "JRuby");
        final RubyModule _JRuby_Rack = defineModuleUnder(context, _JRuby, "Rack");

        // JRuby::Rack::Response
        defineClassUnder(context, _JRuby_Rack, "Response", Response.class, Response.ALLOCATOR);

        // JRuby::Rack::Input
        defineClassUnder(context, _JRuby_Rack, "Input", Input.class, Input.ALLOCATOR);

        // JRuby::Rack::Logger
        final RubyClass _Logger = defineClassUnder(context, _JRuby_Rack, "Logger", Logger.class, Logger.ALLOCATOR);
        // Rails compatibility as it assumes logger.class::DEBUG to work :
        setConstant(context, _Logger, "DEBUG", runtime.newFixnum(Logger.DEBUG));
        setConstant(context, _Logger, "INFO", runtime.newFixnum(Logger.INFO));
        setConstant(context, _Logger, "WARN", runtime.newFixnum(Logger.WARN));
        setConstant(context, _Logger, "ERROR", runtime.newFixnum(Logger.ERROR));
        setConstant(context, _Logger, "FATAL", runtime.newFixnum(Logger.FATAL));
        //_Logger.setConstant("UNKNOWN", runtime.newFixnum(Logger.UNKNOWN));
        // JRuby::Rack::ServletLog
        defineClassUnder(context, _JRuby_Rack, "ServletLog", Logger.ServletLog.class, Logger.ServletLog.ALLOCATOR);

        final RubyModule _Rack = defineModule(context, "Rack");
        final RubyModule _Rack_Handler = defineModuleUnder(context, _Rack, "Handler");

        // Rack::Handler::Servlet
        defineClassUnder(context, _Rack_Handler, "Servlet", Servlet.class, Servlet.ALLOCATOR);
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
