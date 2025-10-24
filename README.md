# JRuby-Rack

[![Gem Version](https://img.shields.io/gem/v/jruby-rack)](https://rubygems.org/gems/jruby-rack)
[![Jar Version](https://img.shields.io/maven-central/v/org.jruby.rack/jruby-rack)](https://central.sonatype.com/artifact/org.jruby.rack/jruby-rack)
[![master Build Status](https://github.com/jruby/jruby-rack/actions/workflows/maven.yml/badge.svg)](https://github.com/jruby/jruby-rack/actions/workflows/maven.yml?query=branch%3Amaster) (master)
[![1.2.x Build Status](https://github.com/jruby/jruby-rack/actions/workflows/maven.yml/badge.svg?branch=1.2-stable)](https://github.com/jruby/jruby-rack/actions/workflows/maven.yml?query=branch%3A1.2-stable) (1.2.x)
 
JRuby-Rack is a lightweight adapter for the Java Servlet environment that allows
any (Ruby) Rack-based application to run unmodified in a Java Servlet container.
JRuby-Rack supports Rails as well as any Rack-compatible Ruby web framework.

For more information on Rack, visit http://rack.github.io/.

## Compatibility

| JRuby-Rack Series                                          | Status     | Rack      | JRuby      | Java | Rails     | Target Servlet API  | Notes                                      |
|------------------------------------------------------------|------------|-----------|------------|------|-----------|---------------------|--------------------------------------------|
| 2.0 (_planned_)                                            | Dev        | 2.2       | 9.4 → 10.0 | 8+   | 6.1 → 8.0 | 5.0+ (Jakarta EE 9) | Pre 5.0 servlet APIs non functional.       |
| 1.3 (master, _unreleased_)                                 | Dev        | 2.2       | 9.4 → 10.0 | 8+   | 6.1 → 8.0 | 4.0 (Java EE 8)     | Servlet 2.5 → 3.1 likely to work fine.     |
| [1.2](https://github.com/jruby/jruby-rack/tree/1.2-stable) | Maintained | 2.2       | 9.3 → 9.4  | 8+   | 5.0 → 7.2 | 3.0 (Java EE 6)     | Servlet 3.1 → 4.0 OK with some containers. |
| [1.1](https://github.com/jruby/jruby-rack/tree/1.1-stable) | EOL        | 1.x → 2.2 | 1.6 → 9.4  | 6+   | 2.1 → 5.2 | 2.5 (Java EE 5)     | Servlet 3.0 → 4.0 OK with some containers. |
| 1.0                                                        | EOL        | 0.9 → 1.x | 1.1 → 1.9  | 5+   | 2.1 → 3.x | 2.5 (Java EE 5)     |                                            |

## Getting Started

The most-common way to use JRuby-Rack with a Java server is to get [Warbler][1].

Warbler depends on the latest version of JRuby-Rack and ensures it gets placed
in your WAR file when it gets built.

If you're assembling your own WAR using other means, you can install the
**jruby-rack** gem. It provides a method to locate the jar file:

```ruby
require 'jruby-rack'
FileUtils.cp JRubyJars.jruby_rack_jar_path, '.'
```

Otherwise you'll need to download the latest [jar release][2], drop it into the
`WEB-INF/lib` directory and configure the `RackFilter` in your application's
`web.xml` (see following examples).

### Rails

Here's sample `web.xml` configuration for Rails. Note the environment and
min/max runtime parameters. For **multi-threaded** (a.k.a. `threadsafe!`)
Rails with a single runtime, set min/max both to 1. Otherwise, define the size
of the runtime pool as you wish.

```xml
<context-param>
  <param-name>rails.env</param-name>
  <param-value>production</param-value>
</context-param>
<context-param>
  <param-name>jruby.min.runtimes</param-name>
  <param-value>1</param-value>
</context-param>
<context-param>
  <param-name>jruby.max.runtimes</param-name>
  <param-value>1</param-value>
</context-param>

<filter>
  <filter-name>RackFilter</filter-name>
  <filter-class>org.jruby.rack.RackFilter</filter-class>
  <!-- optional filter configuration init-params : -->
  <init-param>
    <param-name>resetUnhandledResponse</param-name>
    <param-value>true</param-value> <!-- true (default), false or buffer -->
  </init-param>
  <init-param>
    <param-name>addsHtmlToPathInfo</param-name>
    <param-value>true</param-value> <!-- true (default), false -->
  </init-param>
  <init-param>
    <param-name>verifiesHtmlResource</param-name>
    <param-value>false</param-value> <!-- true, false (default) -->
  </init-param>
</filter>
<filter-mapping>
  <filter-name>RackFilter</filter-name>
  <url-pattern>/*</url-pattern>
</filter-mapping>

<listener>
  <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
</listener>
```

### (Other) Rack Applications

The main difference when using a non-Rails Rack application is that JRuby-Rack
looks for a "rackup" file named `config.ru` in  `WEB-INF/config.ru` or
`WEB-INF/*/config.ru`. Here's a sample `web.xml` configuration :

```xml
<filter>
  <filter-name>RackFilter</filter-name>
  <filter-class>org.jruby.rack.RackFilter</filter-class>
  <!-- optional filter configuration init-params (@see above) -->
</filter>
<filter-mapping>
  <filter-name>RackFilter</filter-name>
  <url-pattern>/*</url-pattern>
</filter-mapping>

<listener>
  <listener-class>org.jruby.rack.RackServletContextListener</listener-class>
</listener>
```

If you don't have a `config.ru` or don't want to include it in your web app, you
can embed it directly in the `web.xml` as follows (using Sinatra as an example):

```xml
<context-param>
  <param-name>rackup</param-name>
  <param-value>
    require 'rubygems'
    gem 'sinatra', '~&gt; 1.3'
    require './lib/app'
    set :run, false
    set :environment, :production
    run Sinatra::Application
  </param-value>
</context-param>
```

Be sure to escape angle-brackets for XML!


## Servlet Filter

JRuby-Rack's main mode of operation is as a filter. This allows requests for
static content to pass through and be served by the application server.
Dynamic requests only happen for URLs that don't have a corresponding file, much
like many Ruby/Rack applications expect. The (default) filter we recommend
using is `org.jruby.rack.RackFilter`, the filter supports the following
(optional) init-params:

- **responseNotHandledStatuses** which statuses (when a filter chain returns)
  should be considered that the response has not been handled (default value:
  "403,404,405") and should be dispatched as a Rack application
- **resetUnhandledResponse** whether an unhandled response from the filter chain
  gets reset (accepts  values "true", "false" and "buffer" to reset the buffer
  only), by default "true"
- **addsHtmlToPathInfo** controls whether the .html suffix is added to the URI
  when checking if the request is for a static page. The default behavior for 
  Rails and many other Ruby applications is to add an `.html` extension to the 
  resource and attempt to handle it before serving a dynamic request on the 
  original URI.  However, this behavior may confuse other servlets in your 
  application that have a wildcard mapping. Defaults to true.
- **verifiesHtmlResource** used with the previous parameter to make sure the
  requested static resource exists before adding the .html request URI suffix.
  Defaults to false.

The application can also be configured to dispatch through a servlet instead of
a filter, the servlet class name is `org.jruby.rack.RackServlet`.

## Servlet Environment Integration

- servlet context is accessible to any application through the Rack environment
  variable `java.servlet_context` (as well as the `$servlet_context` global).
- the (native) servlet request and response objects could be obtained via the
  `java.servlet_request` and `java.servlet_response` keys
- all servlet request attributes are passed through to the Rack environment (and
  thus might override request headers or Rack environment variables)
- servlet sessions can be used as a (java) session store for Rails, session
  attributes with String keys (and String, numeric, boolean, or java
  object values) are automatically copied to the servlet session for you.

## Rails

Several aspects of Rails are automatically set up for you.

- `ActionController::Base.relative_url_root` is set for you automatically
  according to the context root where your webapp is deployed.
- `Rails.logger` output is redirected to the application server log.
- Page caching and asset directories are configured appropriately.

## JRuby Runtime Management

JRuby runtime management and pooling is done automatically by the framework.
For Rack-only applications (and Rails ones from jruby-rack >= 1.3), a single 
shared runtime is created and shared for every request by default.

If `jruby.min.runtimes` and `jruby.max.runtimes` values are
specified pooling of runtimes can be enabled for both types of applications.

We do recommend to boot your runtimes up-front to avoid the cost of initializing
one while a request kicks in and find the pool empty, this can be easily avoided
by setting `jruby.min.runtimes` equal to `jruby.max.runtimes`. You might also
want to consider tuning the `jruby.runtime.acquire.timeout` parameter to not
wait too long when all (max) runtimes from the pool are busy.

## JRuby-Rack Configuration

JRuby-Rack can be configured by setting these key value pairs either
as context init parameters in web.xml or as VM-wide system properties.

- `rackup`: Rackup script for configuring how the Rack application is mounted.
  Required for Rack-based applications other than Rails. Can be omitted if a
  `config.ru` is included in the application root.
- `public.root`: Relative path to the location of your application's static
  assets. Defaults to `*/*`.
- `rails.root`: Root path to the location of the Rails application files.
  Defaults to `*/WEB-INF*`.
- `rails.env`: Specify the Rails environment to run. Defaults to 'production'.
- `rails.relative_url_append`: Specify a path to be appended to the
  `ActionController::Base.relative_url_root` after the context path. Useful
  for running a rails app from the same war as an existing app, under a
  sub-path of the main servlet context root.
- `gem.path`: Relative path to the bundled gem repository. Defaults to
  `/WEB-INF/gems`.
- `jruby.min.runtimes`: For non-threadsafe Rails applications using a runtime
  pool, specify an integer minimum number of runtimes to hold in the pool.
- `jruby.max.runtimes`: For non-threadsafe Rails applications, an integer
  maximum number of runtimes to keep in the pool.
- `jruby.runtime.init.threads`: How many threads to use for initializing
   application runtimes when pooling is used (default is 4).
   It does not make sense to set this value higher than `jruby.max.runtimes`.
- `jruby.runtime.init.serial`: When using runtime pooling, this flag indicates
  that the pool should be created serially in the foreground rather than
  spawning (background) threads, it's by default off (set to false).
  For environments where creating threads is not permitted.
- `jruby.runtime.acquire.timeout`: The timeout in seconds (default 10) to use
  when acquiring a runtime from the pool (while a pool maximum is set), an
  exception will be thrown if a runtime can not be acquired within this time (
  accepts decimal values for fine tuning e.g. 1.25).
- `jruby.runtime.env`: Allows to set a custom ENV hash for your Ruby environment
  and thus insulate the application from the environment it is running. By setting
  this option to en empty string (or 'false') it acts as if the ENV hash was
  cleared out (similar to the now removed `jruby.rack.ignore.env` option).
- `jruby.runtime.env.rubyopt`: Set to true to cause ENV['RUBYOPT']
  to be retained even when using `jruby.runtime.env` to override the environment.
- `jruby.rack.env.gem_path`: If set to `true` (the default) jruby-rack will
  ensure ENV['GEM_PATH'] is altered to include the `gem.path` above. If you set it to a
  value, this value will be used as GEM_PATH, overriding the environment and
  ignoring `gem.path` etc. By setting this option to en empty string the ENV['GEM_PATH'] will
  not be modified by jruby-rack at all and will retain its original values implied by
  the process environment and `jruby.runtime.env` setting.
- `jruby.rack.logging`: Specify the logging device to use. Defaults to
  `servlet_context`. See below.
- `jruby.rack.request.size.initial.bytes`: Initial size for request body memory
   buffer, see also `jruby.rack.request.size.maximum.bytes` below.
- `jruby.rack.request.size.maximum.bytes`: The maximum size for the request in
   memory buffer, if the body is larger than this it gets spooled to a tempfile.
- `jruby.rack.response.dechunk`: Set to false to turn off response dechunking
  (Rails since 3.1 chunks response on `render stream: true`), it's on by default
  as frameworks such as Rails might use `Rack::Chunked::Body` as a Rack response
  body but since most servlet containers perform dechunking automatically things
  might end double-chunked in such cases.
- `jruby.rack.handler.env`: **EXPERIMENTAL** Allows to change Rack's behavior
  on obtaining the Rack environment. The default behavior is that parameter
  parsing is left to be done by the Rack::Request itself (by consuming the
  request body in case of a POST), but if the servlet request's input stream has
  been previously read this leads to a limitation (Rack won't see the POST paras).
  Thus an alternate pure 'servlet' env "conversion" is provided that maps servlet
  parameters (and cookies) directly to Rack params, avoiding Rack's input parsing.

## Initialization

There are often cases where you need to perform custom initialization of the
Ruby environment before booting the application. You can create a file called
`META-INF/init.rb` or `WEB-INF/init.rb` inside the war file for this purpose.
These files, if found, will be evaluated before booting the Rack environment,
allowing you to set environment variables, load scripts, etc.

For plain Rack applications, JRuby-Rack also supports a magic comment to solve
the "rackup" chicken-egg problem (you need Rack's builder loaded before loading
the `config.ru`, yet you may want to setup the gem version from within the rackup
 file). As we ship with the Rack gem bundled, otherwise when executing the
provided `config.ru` the bundled (latest) version of Rack will get loaded.

Use `rack.version` to specify the Rack gem version to be loaded before rackup :

```ruby
# encoding: UTF-8
# rack.version: ~>2.2.10 (before code is loaded gem '~>2.2.10' will be called)
```

Or the equivalent of doing `bundle exec rackup ...` if you're using Bundler :

```ruby
# rack.version: bundler (requires 'bundler/setup' before loading the script)
```

## Logging

JRuby-Rack sets up a delegate logger for Rails that sends logging output to
`javax.servlet.ServletContext#log` by default. If you wish to use a different
logging system, configure `jruby.rack.logging` as follows:

- `servlet_context` (default): Sends log messages to the servlet context.
- `stdout`: Sends log messages to the standard output stream `System.out`.
- `slf4j`: Sends log messages to SLF4J. SLF4J configuration is left up to you,
  please refer to https://www.slf4j.org/manual.html .
- `log4j`: Sends log messages through Log4j. Only Log4j 2.x is supported, for 
- configuration please consult https://logging.apache.org/log4j/2.x/index.html .
- `commons_logging`: Routes logs to commons-logging. You still need to configure
  an underlying logging implementation with JCL. 
  We recommend rather using the logger library wrapper directly when possible.
- `jul`: Directs log messages via Java's core logging facilities (util.logging).

For those loggers that require a specific named logger, set it with the
`jruby.rack.logging.name` option, by default "jruby.rack" name will be used.

## Examples

Some example demo applications are available at [./examples](./examples).

## Building

Checkout the JRuby-Rack code using [git](http://git-scm.com/) :

```shell
git clone git@github.com:jruby/jruby-rack.git
cd jruby-rack
```

Ensure you have a compatible JVM installed. It is required for building and compiling.

Build the .jar using Maven :

```shell
./mvnw install
```

the generated jar should be located at `target/jruby-rack-*.jar`

Alternatively use Rake, e.g. to build the gem (skipping specs) :

```shell
jruby -S rake clean gem SKIP_SPECS=true
```

You can **not** use JRuby-Rack with Bundler directly from the git (or http) URL
(`gem 'jruby-rack', :github => 'jruby/jruby-rack'`) since the included .jar file
is compiled and generated on-demand during the build (it would require us to
package and push the .jar every time a commit changes a source file).

## Releasing

* Make sure auth is configured for "central" repository ID in your `.m2/settings.xml`
* Update the version in `src/main/ruby/jruby/rack/version.rb` to the release version
* `./mvnw release:prepare`
* `./mvnw release:perform` (possibly with `-DuseReleaseProfile=false` due to Javadoc doclint failures for now)
* `rake clean gem SKIP_SPECS=true` and push the gem

## Adding testing for new Rails versions

* Add the new version to `.github/workflows/maven.yml` under the `matrix` section
* Add a new configuration to the `Appraisals` file, then
    ```bundle exec appraisal generate```
* Generate a new stub Rails application for the new version
    ```shell
    VERSION=rails72
    cd src/spec/stub
    rm -rf $VERSION && BUNDLE_GEMFILE=~/Projects/community/jruby-rack/gemfiles/${VERSION}_rack22.gemfile bundle exec rails new $VERSION --minimal --skip-git --skip-docker --skip-active-model --skip-active-record --skip-test --skip-system-test --skip-dev-gems --skip-bundle --skip-keeps --skip-asset-pipeline --skip-ci --skip-brakeman --skip-rubocop
    ```
* Manual changes to make to support testing
  * In `config/production.rb` comment out the default `config.logger` value so jruby-rack applies its own `RailsLogger`.  

## Support

Please use [github][3] to file bugs, patches and/or pull requests.
More information at the [wiki][4] or ask us at **#jruby**'s IRC channel.

[1]: https://github.com/jruby/warbler
[2]: https://central.sonatype.com/artifact/org.jruby.rack/jruby-rack
[3]: https://github.com/jruby/jruby-rack/issues
[4]: https://github.com/jruby/jruby-rack/wiki
