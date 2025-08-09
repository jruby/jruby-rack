/*
 * The MIT License
 *
 * Copyright (c) 2014 Karol Bucek LTD.
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
package org.jruby.rack.util;

import java.io.IOException;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyException;
import org.jruby.RubyString;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author kares
 */
public abstract class ExceptionUtils {

    public static RaiseException newRuntimeError(final Ruby runtime, final Throwable cause) {
        return newRaiseException(runtime, runtime.getRuntimeError(), cause);
    }

    public static RaiseException newArgumentError(final Ruby runtime, final RuntimeException cause) {
        return newRaiseException(runtime, runtime.getArgumentError(), cause);
    }

    public static RaiseException newIOError(final Ruby runtime, final IOException cause) {
        RaiseException raise = runtime.newIOErrorFromException(cause);
        raise.initCause(cause);
        return raise;
    }

    private static RaiseException newRaiseException(final Ruby runtime,
        final RubyClass errorClass, final Throwable cause) {
        final String message = cause.getMessage();
        RaiseException raise = RaiseException.from(runtime, errorClass, message);
        raise.initCause(cause);
        return raise;
    }

    public static CharSequence formatError(final RubyException error) {
        final StringBuilder out = new StringBuilder(128);
        appendError(error, out); return out;
    }

    private static void appendInspect(final RubyException error, final StringBuilder out) {
        final RubyClass errorClass = error.getMetaClass().getRealClass();
        if ( error.getMessage() != null && ! error.getMessage().isNil() ) {
            out.append("#<").append( errorClass.getName() ).append(": ");
            out.append( error.getMessage().asString() ).append('>');
        }
        else {
            out.append( errorClass.getName() );
        }
    }

    public static void appendError(final RubyException error, final StringBuilder out) {
        appendInspect(error, out);
        appendBacktrace(error, out.append('\n'));
    }

    public static void appendBacktrace(final RubyException error, final StringBuilder out) {
        appendBacktrace(error, 0, out);
    }

    public static void appendBacktrace(final RubyException error, final int skip,
        final StringBuilder out) {
        final ThreadContext context = error.getRuntime().getCurrentContext();
        final IRubyObject backtrace = error.callMethod(context, "backtrace");
        if ( ! backtrace.isNil() ) {
            final RubyArray<?> trace = backtrace.convertToArray();
            out.ensureCapacity(out.length() + 24 * trace.getLength());
            for ( int i = skip; i < trace.getLength(); i++ ) {
                IRubyObject stackTraceLine = trace.eltInternal(i);
                if ( stackTraceLine instanceof RubyString ) {
                    out.append("\tfrom ").append(stackTraceLine).append('\n');
                }
            }
        }
    }

}
