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
package org.jruby.rack.ext;

import javax.servlet.ServletContext;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyException;
import org.jruby.RubyObject;
import org.jruby.RubyProc;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackLogger;
import org.jruby.rack.logging.ServletContextLogger;
import org.jruby.rack.util.ExceptionUtils;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * JRuby::Rack::Logger compatible with *logger.rb*
 *
 * @author kares
 */
@JRubyClass(name="JRuby::Rack::Logger")
public class Logger extends RubyObject { // implements RackLogger

    static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Logger(runtime, klass);
        }
    };

    // Logger::Severity :

    // Low-level information, mostly for developers.
    static final int DEBUG = 0;
    // Generic (useful) information about system operation.
    static final int INFO = 1;
    // A warning.
    static final int WARN = 2;
    // A handleable error condition.
    static final int ERROR = 3;
    // An unhandleable error that results in a program crash.
    static final int FATAL = 4;
    // An unknown message that should always be logged.
    static final int UNKNOWN = 5;

    private static final int NOT_SET = -1;

    private int level = NOT_SET;

    private RackLogger logger; // the "real" logger
    //private Boolean loggerFormatting;
    private IRubyObject formatter = null; // optional
    private IRubyObject progname;

    protected Logger(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @Override
    @JRubyMethod(required = 0)
    public IRubyObject initialize(final ThreadContext context) {
        IRubyObject jrubyRack = context.runtime.getModule("JRuby").getConstant("Rack");
        initialize( jrubyRack.callMethod(context, "context") ); // JRuby::Rack.context
        return this;
    }

    @JRubyMethod(required = 1)
    public IRubyObject initialize(final ThreadContext context, final IRubyObject logger) {
        initialize(logger);
        return this;
    }

    private void initialize(final IRubyObject context) {
        if ( context.isNil() ) throw getRuntime().newArgumentError("no context");

        if ( context instanceof RackLogger ) {
            this.logger = (RackLogger) context;
        }
        else if ( context instanceof RackContext ) {
            this.logger = ((RackContext) context).getConfig().getLogger();
        }
        else {
            this.logger = (RackLogger) context.toJava(RackLogger.class);
        }
    }

    @JRubyMethod
    public IRubyObject initialize_copy(final ThreadContext context, final IRubyObject logger) {
        Logger other = (Logger) logger;

        this.level = other.level;
        this.logger = other.logger;
        this.formatter = other.formatter;
        this.progname = other.progname;

        return this;
    }

    @JRubyMethod
    public IRubyObject real_logger(final ThreadContext context) {
        return JavaEmbedUtils.javaToRuby(context.runtime, logger);
    }

    public RackLogger getRealLogger() {
        return logger;
    }

    @JRubyMethod(name = "level", alias = "sev_threshold")
    public IRubyObject get_level(final ThreadContext context) {
        if ( this.level == NOT_SET ) return context.nil;
        return context.runtime.newFixnum(this.level);
    }

    @JRubyMethod(name = "level=", alias = "sev_threshold=")
    public IRubyObject set_level(final ThreadContext context, final IRubyObject level) {
        if ( level.isNil() ) { this.level = NOT_SET; return level; }
        this.level = (int) level.convertToInteger("to_i").getLongValue();
        return get_level(context);
    }

    @JRubyMethod(name = "debug?")
    public IRubyObject is_debug(final ThreadContext context) {
        return context.runtime.newBoolean( isDebugEnabled() );
    }

    public boolean isDebugEnabled() { return isEnabledFor(DEBUG); }

    @JRubyMethod(name = "info?")
    public IRubyObject is_info(final ThreadContext context) {
        return context.runtime.newBoolean( isInfoEnabled() );
    }

    public boolean isInfoEnabled() { return isEnabledFor(INFO); }

    @JRubyMethod(name = "warn?")
    public IRubyObject is_warn(final ThreadContext context) {
        return context.runtime.newBoolean( isWarnEnabled() );
    }

    public boolean isWarnEnabled() { return isEnabledFor(WARN); }

    @JRubyMethod(name = "error?")
    public IRubyObject is_error(final ThreadContext context) {
        return context.runtime.newBoolean( isErrorEnabled() );
    }

    public boolean isErrorEnabled() { return isEnabledFor(ERROR); }

    @JRubyMethod(name = "fatal?")
    public IRubyObject is_fatal(final ThreadContext context) {
        return context.runtime.newBoolean( isFatalEnabled() );
    }

    public boolean isFatalEnabled() { return isEnabledFor(FATAL); }

    private boolean isEnabledFor(final int severity) {
        return isEnabledFor(severity, mapLevel(severity));
    }

    private boolean isEnabledFor(final int severity,
        final RackLogger.Level loggerLevel) {
        if ( loggerLevel == null ) return level <= severity;
        if ( level == NOT_SET ) return logger.isEnabled(loggerLevel);
        return level <= severity && logger.isEnabled(loggerLevel);
    }

    private static RackLogger.Level mapLevel(final int level) {
        switch (level) {
            case DEBUG: return RackLogger.Level.DEBUG;
            case INFO : return RackLogger.Level.INFO ;
            case WARN : return RackLogger.Level.WARN ;
            case ERROR: return RackLogger.Level.ERROR;
            case FATAL: return RackLogger.Level.FATAL;
        }
        return null;
    }

    @JRubyMethod(name = "progname")
    public IRubyObject get_progname(final ThreadContext context) {
        return progname;
    }

    @JRubyMethod(name = "progname=")
    public IRubyObject set_progname(final ThreadContext context, final IRubyObject progname) {
        return this.progname = progname;
    }

    @JRubyMethod(name = "formatter")
    public IRubyObject get_formatter(final ThreadContext context) {
        return this.formatter;
    }

    @JRubyMethod(name = "formatter=")
    public IRubyObject set_formatter(final ThreadContext context, final IRubyObject formatter) {
        if ( logger instanceof RackLogger.Base ) {
            final RackLogger.Base logger = (RackLogger.Base) this.logger;
            //if ( loggerFormatting == null ) loggerFormatting = logger.isFormatting();
            if ( formatter.isNil() ) {
                //if ( loggerFormatting != null && loggerFormatting.booleanValue() ) {
                    logger.setFormatting(true);
                //}
            }
            else { // if formatter set disable 'potential' logger formatting
                logger.setFormatting(false);
            }
        }
        return this.formatter = formatter;
    }

    @JRubyMethod
    public IRubyObject close(final ThreadContext context) {
        return context.nil; // @logdev.close if @logdev
    }

    //
    // Log a +DEBUG+ message.
    //
    @JRubyMethod(name = "debug")
    public IRubyObject debug(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        return context.runtime.newBoolean( add(DEBUG, context, msg, block) );
    }

    //
    // :call-seq:
    // info(message)
    // info(progname, &block)
    //
    // Log an +INFO+ message.
    //
    // +message+:: The message to log; does not need to be a String.
    // +progname+:: In the block form, this is the #progname to use in the
    // log message. The default can be set with #progname=.
    // +block+:: Evaluates to the message to log. This is not evaluated unless
    // the logger's level is sufficient to log the message. This
    // allows you to create potentially expensive logging messages that
    // are only called when the logger is configured to show them.
    //
    // === Examples
    //
    // logger.info("MainApp") { "Received connection from #{ip}" }
    // # ...
    // logger.info "Waiting for input from user"
    // # ...
    // logger.info { "User typed #{input}" }
    //
    // You'll probably stick to the second form above, unless you want to provide a
    // program name (which you can do with #progname= as well).
    //#
    // === Return
    //
    // See #add.
    //
    @JRubyMethod(name = "info")
    public IRubyObject info(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        return context.runtime.newBoolean( add(INFO, context, msg, block) );
    }

    @JRubyMethod(name = "info")
    public IRubyObject info(final ThreadContext context, final Block block) {
        return info(context, context.nil, block);
    }
    
    //
    // Log a +WARN+ message.
    //
    @JRubyMethod(name = "warn")
    public IRubyObject warn(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        return context.runtime.newBoolean( add(WARN, context, msg, block) );
    }

    @JRubyMethod(name = "warn")
    public IRubyObject warn(final ThreadContext context, final Block block) {
        return warn(context, context.nil, block);
    }

    //
    // Log a +ERROR+ message.
    //
    @JRubyMethod(name = "error")
    public IRubyObject error(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        return context.runtime.newBoolean( add(ERROR, context, msg, block) );
    }

    @JRubyMethod(name = "error")
    public IRubyObject error(final ThreadContext context, final Block block) {
        return error(context, context.nil, block);
    }

    //
    // Log a +FATAL+ message.
    //
    @JRubyMethod(name = "fatal")
    public IRubyObject fatal(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        return context.runtime.newBoolean( add(FATAL, context, msg, block) );
    }

    @JRubyMethod(name = "fatal")
    public IRubyObject fatal(final ThreadContext context, final Block block) {
        return fatal(context, context.nil, block);
    }

    //
    // Log an +UNKNOWN+ message.
    // This will be printed no matter what the logger's level is.
    //
    @JRubyMethod(name = "unknown")
    public IRubyObject unknown(final ThreadContext context,
        final IRubyObject msg, final Block block) {
        // NOTE possibly - "somehow" support UNKNOWN in RackLogger ?!
        return context.runtime.newBoolean( add(UNKNOWN, context, msg, block) );
    }

    @JRubyMethod(name = "unknown")
    public IRubyObject unknown(final ThreadContext context, final Block block) {
        return unknown(context, context.nil, block);
    }

    // def add(severity, message = nil, progname = nil, &block)
    @JRubyMethod(name = "add", required = 1, optional = 2)
    public IRubyObject add(final ThreadContext context,
        final IRubyObject[] args, final Block block) {
        int severity = UNKNOWN;
        final IRubyObject sev = args[0];
        if ( ! sev.isNil() ) {
            severity = (int) sev.convertToInteger("to_i").getLongValue();
        }
        IRubyObject msg;
        if ( args.length > 1 ) {
            msg = args[1];
            if ( msg.isNil() && args.length > 2 ) msg = args[2];
        }
        else msg = context.nil;

        return context.runtime.newBoolean( add(severity, context, msg, block) );
    }


    // def add(severity, message = nil, progname = nil, &block)
    @JRubyMethod(name = "add")
    public IRubyObject add(final ThreadContext context,
        final IRubyObject severity, final IRubyObject msg,
        final IRubyObject progname, final Block block) {
        // NOTE possibly - "somehow" support UNKNOWN in RackLogger ?!
        return context.runtime.newBoolean( add(UNKNOWN, context, msg, block) );
    }

    private boolean add(final int severity, final ThreadContext context,
        IRubyObject msg, final Block block) {
        // severity ||= UNKNOWN
        final RackLogger.Level loggerLevel = mapLevel(severity);

        if ( ! isEnabledFor(severity, loggerLevel) ) return true;

        IRubyObject progname = null;
        // progname ||= @progname
        if ( msg.isNil() ) {
            if ( block.isGiven() ) {
                progname = msg;
                msg = block.yieldSpecific(context);
            }
            else {
                //msg = progname;
            }
        }
        if ( formatter != null ) { // formatter is optional and null by default
            if ( progname == null ) {
                progname = this.progname == null ? context.nil : this.progname;
            }
            final long datetime = System.currentTimeMillis();
            msg = format_message(context, severity, datetime, progname, msg);
        }
        else if ( msg instanceof RubyException ) { // print backtrace for error
            final RubyException error = (RubyException) msg;
            error.prepareIntegratedBacktrace(context, null);
            doLog( loggerLevel, ExceptionUtils.formatError(error).toString() );
            return true;
        }
        // @logdev.write(format_message(format_severity(severity), Time.now, progname, message))
        if ( ! msg.isNil() ) doLog( loggerLevel, msg.asString() ); // TODO CharSequence ?!
        return true;
    }

    //
    // Dump given message to the log device without any formatting.
    // If no log device exists, return +nil+.
    //
    @JRubyMethod(name = "<<")
    public IRubyObject append(final ThreadContext context, final IRubyObject msg) {
        final RubyString msgString = msg.asString();
        doLog(msgString); return msgString.rubyLength(context);
    }

    // private

    @JRubyMethod(visibility = Visibility.PRIVATE, required = 4)
    public IRubyObject format_message(final ThreadContext context,
        final IRubyObject[] args) {
        if ( formatter instanceof RubyProc ) {
            return ((RubyProc) formatter).call(context, args);
        }
        return formatter.callMethod(context, "call", args);
    }

    private IRubyObject format_message(final ThreadContext context,
        final int severityVal, final long datetimeMillis,
        final IRubyObject progname, final IRubyObject msg) {
        final IRubyObject severity =
            RubyString.newStringShared(context.runtime, formatSeverity(severityVal));
        final RubyTime datetime = RubyTime.newTime(context.runtime, datetimeMillis);
        return format_message(context, new IRubyObject[] { severity, datetime, progname, msg });
    }

    @JRubyMethod(visibility = Visibility.PRIVATE)
    public IRubyObject format_severity(final ThreadContext context, final IRubyObject sev) {
        final int severity = (int) sev.convertToInteger("to_i").getLongValue();
        return RubyString.newStringShared(context.runtime, formatSeverity(severity));
    }

    private static final ByteList FORMATTED_DEBUG =
            new ByteList(new byte[] { 'D','E','B','U','G' }, false);
    private static final ByteList FORMATTED_INFO =
            new ByteList(new byte[] { 'I','N','F','O' }, false);
    private static final ByteList FORMATTED_WARN =
            new ByteList(new byte[] { 'W','A','R','N' }, false);
    private static final ByteList FORMATTED_ERROR =
            new ByteList(new byte[] { 'E','R','R','O','R' }, false);
    private static final ByteList FORMATTED_FATAL =
            new ByteList(new byte[] { 'F','A','T','A','L' }, false);
    private static final ByteList FORMATTED_ANY =
            new ByteList(new byte[] { 'A','N','Y' }, false);

    private static ByteList formatSeverity(final int severity) {
        switch ( severity) {
            case DEBUG: return FORMATTED_DEBUG;
            case INFO : return FORMATTED_INFO ;
            case WARN : return FORMATTED_WARN ;
            case ERROR: return FORMATTED_ERROR;
            case FATAL: return FORMATTED_FATAL;
        }
        return FORMATTED_ANY;
    }

    /*
    private static String formatSeverity(final int severity) {
        switch ( severity) {
            case DEBUG: return "DEBUG";
            case INFO : return "INFO" ;
            case WARN : return "WARN" ;
            case ERROR: return "ERROR";
            case FATAL: return "FATAL";
        }
        return "ANY";
    } */

    // RackLogger

    @Override
    public Object toJava(Class target) {
        // NOTE: maybe this is not a good idea ?!
        if ( RackLogger.class == target ) return logger;
        return super.toJava(target);
    }

    private void doLog(RackLogger.Level level, String message) {
        logger.log( level, message );
    }

    private void doLog(RackLogger.Level level, RubyString message) {
        logger.log( level, message.toString() );
    }

    private void doLog(RubyString message) {
        logger.log( message.toString() );
    }

    /*
    @Override
    public void log(String message) {
        logger.log(message);
    }

    @Override
    public void log(String message, Throwable ex) {
        logger.log(message, ex);
    }

    @Override
    public void log(Level level, String message) {
        logger.log(level, message);
    }

    @Override
    public void log(Level level, String message, Throwable ex) {
        logger.log(level, message, ex);
    }

    @Override @Deprecated
    public void log(String level, String message) {
        logger.log(level, message);
    }

    @Override @Deprecated
    public void log(String level, String message, Throwable ex) {
        logger.log(level, message, ex);
    } */

    // LoggerSilence API :

    private static boolean silencer = false; // we're NOT true by default!

    @JRubyMethod(name= "silencer", meta = true)
    public static IRubyObject get_silencer(final ThreadContext context, final IRubyObject self) {
        return context.runtime.newBoolean(silencer);
    }

    @JRubyMethod(name = "silencer=", meta = true)
    public static IRubyObject set_silencer(final ThreadContext context, final IRubyObject self,
        final IRubyObject value) {
        return context.runtime.newBoolean(silencer = value.isTrue());
    }

    @JRubyMethod(name = "silence")
    public IRubyObject silence(final ThreadContext context, final Block block) {
        return doSilence(ERROR, context, block); // temp_level = Logger::ERROR
    }

    @JRubyMethod(name = "silence", required = 1)
    public IRubyObject silence(final ThreadContext context,
        final IRubyObject temp_level, final Block block) {
        final int tempLevel = (int) temp_level.convertToInteger("to_i").getLongValue();
        return doSilence(tempLevel, context, block);
    }

    private IRubyObject doSilence(final int tempLevel,
        final ThreadContext context, final Block block) {
        if ( silencer ) {
            try { // not implemented - on purpose!
                return block.yield(context, this);
            }
            finally { /* noop */ }
        }
        else {
            return block.yield(context, this);
        }
    }

    // (old) BufferedLogger API compatibility :

    @JRubyMethod(name = "flush", alias = { "auto_flushing", "auto_flushing=" })
    public IRubyObject stub(final ThreadContext context) {
        return context.nil;
    }

    /**
     * @deprecated Likely, no longer used at all, mostly for 1.1 compatibility.
     */
    @JRubyClass(name="JRuby::Rack::ServletLog")
    public static class ServletLog extends RubyObject {

        static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
            public IRubyObject allocate(Ruby runtime, RubyClass klass) {
                return new ServletLog(runtime, klass);
            }
        };

        private RackLogger context;

        protected ServletLog(Ruby runtime, RubyClass metaClass) {
            super(runtime, metaClass);
        }

        @JRubyMethod(required = 0, optional = 1)
        public IRubyObject initialize(final ThreadContext context, final IRubyObject[] args) {
            final IRubyObject rackContext;
            if ( args != null && args.length > 0 ) rackContext = args[0];
            else {
                IRubyObject jrubyRack = context.runtime.getModule("JRuby").getConstant("Rack");
                rackContext = jrubyRack.callMethod(context, "context"); // JRuby::Rack.context
            }
            if ( rackContext.isNil() ) {
                throw context.runtime.newArgumentError("no context");
            }
            if ( rackContext instanceof RackContext ) {
                this.context = (RackContext) rackContext;
            }
            else {
                try {
                    RackLogger logger = (RackLogger) rackContext.toJava(RackLogger.class);
                    this.context = logger;
                }
                catch (RaiseException e) { // TypeError
                    final IRubyObject error = e.getException();
                    if ( error == null && ! context.runtime.getTypeError().isInstance(error) ) {
                        throw e;
                    }
                    // support passing in a ServletContext instance (for convenience) :
                    try {
                        ServletContext servletContext = (ServletContext) rackContext.toJava(ServletContext.class);
                        this.context = new ServletContextLogger(servletContext);
                    }
                    catch (RaiseException fail) {
                        throw context.runtime.newArgumentError("context is not a ServletContext nor a RackContext");
                    }
                }
            }
            return this;
        }

        @JRubyMethod
        public IRubyObject write(final IRubyObject msg) {
            context.log( msg.toString() );
            return msg;
        }

        @JRubyMethod
        public IRubyObject puts(final IRubyObject msg) {
            return write(msg);
        }

        @JRubyMethod(name = "close", alias = "flush")
        public IRubyObject noop(final ThreadContext context) {
            return context.nil; /* NOOP */
        }

    }

}