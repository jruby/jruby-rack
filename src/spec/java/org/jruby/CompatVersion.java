package org.jruby;

/**
 * This was removed from JRuby Core as of 10.0; but deprecated and unused for a long time.
 * <p/>
 * While this is not actually used at runtime unless people specifically invoke the methods on Rack Config, various
 * tests mock RackConfig which causes tests to try and load the class. So we add back/override a minimal version here
 * to allow the tests to work on JRuby 10, and be able to add JRuby 10 and Rails 8.0 support to the 1.2.x line.
 * <p/>>
 * <a href="https://github.com/jruby/jruby/blob/jruby-9.4/core/src/main/java/org/jruby/CompatVersion.java">CompatVersion@9.4 source</a>}
 * @deprecated since JRuby 9.2 with no replacement; for removal with jruby-rack 1.3.0
 */
public enum CompatVersion {
    RUBY1_8, // used in specs
    RUBY2_1, // used as default by jruby-rack
    BOTH     // used as the default by JRuby 9.3/9.4 at runtime
}
