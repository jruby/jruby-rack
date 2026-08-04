package org.jruby.rack.util;

import org.jruby.*;
import org.jruby.api.Access;
import org.jruby.api.Define;
import org.jruby.ext.rbconfig.RbConfigLibrary;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Define compatibility overloads to be able to support JRuby 9.4 through 19.1 within a single build. This should be
 * removed and unlined to the JRuby10 helper once 9.4 support is removed.
 */
public abstract class JRubyCompat {
    private static JRubyCompat INSTANCE;

    private static JRubyCompat chooseImpl(ThreadContext context) {
        if (INSTANCE == null) {
            INSTANCE = RbConfigLibrary.getRuntimeVerStr(context.runtime).startsWith("3.1") ? new JRuby9Compat() : new JRuby10Compat();
        }
        return INSTANCE;
    }

    public static RubyModule getModule(ThreadContext context, String moduleName) {
        return chooseImpl(context).moduleFrom(context, moduleName);
    }

    public static RubyModule defineModule(ThreadContext context, String moduleName) {
        return chooseImpl(context).defineModuleFrom(context, moduleName);
    }

    public static RubyModule defineModuleUnder(ThreadContext context, RubyModule rubyModule, String name) {
        return chooseImpl(context).defineModuleUnderFrom(context, rubyModule, name);
    }

    public static RubyClass getClass(final ThreadContext context, String... names) {
        return chooseImpl(context).classFrom(context, names);
    }

    public static RubyClass defineClassUnder(ThreadContext context, RubyModule under, String className, Class<?> javaClazz, ObjectAllocator allocator) {
        return chooseImpl(context).defineClassUnderFrom(context, under, className, allocator, javaClazz);
    }

    public static void setConstant(ThreadContext context, RubyClass rubyClass, String name, RubyFixnum value) {
        chooseImpl(context).setConstantFrom(context, rubyClass, name, value);
    }

    public static int toInt(ThreadContext context, final IRubyObject object) {
        return chooseImpl(context).asInt(context, object.convertToInteger("to_i"));
    }

    public static long toLong(ThreadContext context, final IRubyObject object) {
        return chooseImpl(context).asLong(context, object.convertToInteger("to_i"));
    }

    public static void clearString(ThreadContext context, RubyString string) {
        chooseImpl(context).clear(context, string);
    }

    protected abstract RubyModule moduleFrom(ThreadContext context, String moduleName);
    protected abstract RubyModule defineModuleFrom(ThreadContext context, String moduleName);
    protected abstract RubyModule defineModuleUnderFrom(ThreadContext context, RubyModule rubyModule, String name);

    protected abstract RubyClass classFrom(ThreadContext context, String... names);
    protected abstract RubyClass defineClassUnderFrom(ThreadContext context, RubyModule under, String className, ObjectAllocator allocator, Class<?> javaClazz);
    protected abstract void setConstantFrom(ThreadContext context, RubyClass rubyClass, String name, RubyFixnum value);

    protected abstract int asInt(ThreadContext context, RubyInteger rubyInt);
    protected abstract long asLong(ThreadContext context, RubyInteger rubyInt);
    protected abstract void clear(ThreadContext context, RubyString string);

    @SuppressWarnings("deprecation")
    private static final class JRuby9Compat extends JRubyCompat {

        @Override
        protected RubyModule moduleFrom(ThreadContext context, String moduleName) {
            return objectClass(context).getModule(moduleName);
        }

        @Override
        protected RubyModule defineModuleFrom(ThreadContext context, String moduleName) {
            return context.runtime.defineModuleUnder(moduleName, objectClass(context));
        }

        @Override
        protected RubyModule defineModuleUnderFrom(ThreadContext context, RubyModule rubyModule, String name) {
            return rubyModule.defineModuleUnder(name);
        }

        @Override
        protected RubyClass classFrom(ThreadContext context, String... names) {
            RubyModule module = objectClass(context);
            for (String name : names) {
                module = module.getModule(name);
            }
            return (RubyClass) module;
        }

        @Override
        protected RubyClass defineClassUnderFrom(ThreadContext context, RubyModule under, String className, ObjectAllocator allocator, Class<?> javaClazz) {
            final RubyClass rubyClazz = under.defineClassUnder(className, context.runtime.getObject(), allocator);
            rubyClazz.defineAnnotatedMethods(javaClazz);
            return rubyClazz;
        }

        @Override
        protected void setConstantFrom(ThreadContext context, RubyClass rubyClass, String name, RubyFixnum value) {
            rubyClass.setConstant(name, value);
        }

        @Override
        protected int asInt(ThreadContext context, RubyInteger rubyInt) {
            return rubyInt.getIntValue();
        }

        @Override
        protected long asLong(ThreadContext context, RubyInteger rubyInt) {
            return rubyInt.getLongValue();
        }

        @Override
        protected void clear(ThreadContext context, RubyString string) {
            string.clear();
        }

        private static RubyClass objectClass(ThreadContext currentContext) {
            return currentContext.getRuntime().getObject();
        }
    }

    private static class JRuby10Compat extends JRubyCompat {
        @Override
        protected RubyModule defineModuleFrom(ThreadContext context, String moduleName) {
            return Define.defineModule(context, moduleName);
        }

        @Override
        protected RubyModule defineModuleUnderFrom(ThreadContext context, RubyModule rubyModule, String name) {
            return rubyModule.defineModuleUnder(context, name);
        }

        @Override
        protected RubyModule moduleFrom(ThreadContext context, String moduleName) {
            return Access.getModule(context, moduleName);
        }

        @Override
        protected RubyClass classFrom(ThreadContext context, String... names) {
            return Access.getClass(context, names);
        }

        @Override
        protected RubyClass defineClassUnderFrom(ThreadContext context, RubyModule under, String className, ObjectAllocator allocator, Class<?> javaClazz) {
            final RubyClass rubyClazz = under.defineClassUnder(context, className, context.runtime.getObject(), allocator);
            rubyClazz.defineMethods(context, javaClazz);
            return rubyClazz;
        }

        @Override
        protected void setConstantFrom(ThreadContext context, RubyClass rubyClass, String name, RubyFixnum value) {
            rubyClass.setConstant(context, name, value);
        }

        @Override
        protected int asInt(ThreadContext context, RubyInteger rubyInt) {
            return rubyInt.asInt(context);
        }

        @Override
        protected long asLong(ThreadContext context, RubyInteger rubyInt) {
            return rubyInt.asLong(context);
        }

        @Override
        protected void clear(ThreadContext context, RubyString string) {
            string.clear(context);
        }
    }
}
