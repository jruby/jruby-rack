# JRuby trunk has its jars in the boot classpath; this breaks
# Buildr 1.3.0's RSpec integration. This shim makes the JRuby 
# jar available in the regular java.class.path property, which
# Buildr uses. Patch for Buildr filed as
# https://issues.apache.org/jira/browse/BUILDR-66

if defined?(JRUBY_VERSION)
  if (cpath = java.lang.System.getProperty('java.class.path')) !~ /jruby/
    jruby_jar = java.lang.System.getProperty('sun.boot.class.path') =~ /([^:]+jruby[^:]+)/ && $1
    cpath << File::PATH_SEPARATOR unless cpath.empty?
    cpath << jruby_jar
    java.lang.System.setProperty('java.class.path', cpath)
  end
end
