package org.jruby;

/**
 * Removed from JRuby Core as of 10.0; but deprecated and unused for a long time.
 * <p/>
 * Added back to jruby-rack 1.2.x to allow JRuby 10 support without an API changed, but
 * will be removed in jruby-rack 1.3.0
 * <p/>
 * @link https://github.com/jruby/jruby/blob/jruby-9.3/core/src/main/java/org/jruby/CompatVersion.java
 * @deprecated since JRuby 9.2 with no replacement; for removal with jruby-rack 1.3.0
 */
@Deprecated
public enum CompatVersion {

    @Deprecated RUBY1_8,
    @Deprecated RUBY1_9,
    @Deprecated RUBY2_0,
    @Deprecated RUBY2_1,
    @Deprecated BOTH;

    @Deprecated
    public boolean is1_9() {
        return this == RUBY1_9 || this == RUBY2_0 || this == RUBY2_1;
    }

    @Deprecated
    public boolean is2_0() {
        return this == RUBY2_0 || this == RUBY2_1;
    }

    @Deprecated
    public static CompatVersion getVersionFromString(String compatString) {
        if (compatString.equalsIgnoreCase("RUBY1_8")) {
            return CompatVersion.RUBY1_8;
        } else if (compatString.equalsIgnoreCase("1.8")) {
            return CompatVersion.RUBY1_8;
        } else if (compatString.equalsIgnoreCase("RUBY1_9")) {
            return CompatVersion.RUBY1_9;
        } else if (compatString.equalsIgnoreCase("1.9")) {
            return CompatVersion.RUBY1_9;
        } else if (compatString.equalsIgnoreCase("RUBY2_0")) {
            return CompatVersion.RUBY2_0;
        } else if (compatString.equalsIgnoreCase("2.0")) {
            return CompatVersion.RUBY2_0;
        } else if (compatString.equalsIgnoreCase("RUBY2_1")) {
            return CompatVersion.RUBY2_1;
        } else if (compatString.equalsIgnoreCase("2.1")) {
            return CompatVersion.RUBY2_1;
        } else {
            return null;
        }
    }

    @Deprecated
    public static boolean shouldBindMethod(CompatVersion runtimeVersion, CompatVersion methodVersion) {
        if (runtimeVersion == RUBY1_8) return methodVersion == RUBY1_8 || methodVersion == BOTH;
        if (runtimeVersion == RUBY1_9) return methodVersion == RUBY1_9 || methodVersion == BOTH;
        if (runtimeVersion == RUBY2_0) return methodVersion == RUBY1_9 || methodVersion == RUBY2_0 || methodVersion == BOTH;
        if (runtimeVersion == RUBY2_1) return methodVersion == RUBY1_9 || methodVersion == RUBY2_0 || methodVersion == RUBY2_1 || methodVersion == BOTH;
        return false;
    }
}
