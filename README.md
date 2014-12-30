# JRuby-Rack

JRuby-Rack is a lightweight adapter for the Java Servlet environment that allows
any (Ruby) Rack-based application to run unmodified in a Java Servlet container.
JRuby-Rack supports Rails as well as any Rack-compatible Ruby web framework.

For more information on Rack, visit http://rack.github.io/.

[![Gem Version](https://badge.fury.io/rb/jruby-rack.png)][8]
[![Build Status][9]](http://travis-ci.org/jruby/jruby-rack)

## Compatibility

JRuby-Rack 1.1.x aims to be compatible with JRuby >= 1.6.4 (we recommend 1.7.x),
Generally, any container that supports Java Servlet >= 2.5 (JEE 5) is supported.

## Getting Started

The most-common way to use JRuby-Rack with a Java server is to get [Warbler][1].
Warbler depends on the latest version of JRuby-Rack and ensures it gets placed
in your WAR file when it gets built.

If you're assembling your own WAR using other means, you can install the
**jruby-rack** gem. It provides a method to locate the jar file:

    require 'jruby-rack'
    FileUtils.cp JRubyJars.jruby_rack_jar_path, '.'

Otherwise you'll need to download the latest [jar release][2], drop it into the
*WEB-INF/lib* directory and configure the `RackFilter` in your application's
*web.xml* (see following examples).

Alternatively you can use a server built upon JRuby-Rack such as [Trinidad][3]
with sensible defaults, without the need to configure a deployment descriptor.

### Rails

Here's sample *web.xml* configuration for Rails. Note the environment and
min/max runtime parameters. For **multi-threaded** (a.k.a. `threadsafe!`)
Rails with a single runtime, set min/max both to 1. Otherwise, define the size
of the runtime pool as you wish.

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

### (Other) Rack Applications

The main difference when using a non-Rails Rack application is that JRuby-Rack
looks for a "rackup" file named **config.ru** in  `WEB-INF/config.ru` or
`WEB-INF/*/config.ru`. Here's a sample *web.xml* configuration :

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

If you don't have a *config.ru* or don't want to include it in your web app, you
can embed it directly in the *web.xml* as follows (using Sinatra as an example):

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

Be sure to escape angle-brackets for XML !


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
  when checking if the request is for a static page
- **verifiesHtmlResource** used with the previous parameter to makee sure the
  requested static resource exist before adding the .html request URI suffix

The application can also be configured to dispatch through a servlet instead of
a filter, the servlet class name is `org.jruby.rack.RackServlet`.

## Servlet Environment Integration

- servlet context is accessible to any application through the Rack environment
  variable *java.servlet_context* (as well as the `$servlet_context` global).
- the (native) servlet request and response objects could be obtained via the
  *java.servlet_request* and *java.servlet_response* keys
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
In the case of Rails, runtimes are pooled by default (the default will most
likely change with the adoption of Rails 4.0). For other Rack applications a
single shared runtime is created and shared for every request by default.
As of **1.1.9** if *jruby.min.runtimes* and *jruby.max.runtimes* values are
specified pooling is supported for plain Rack applications as well.

We do recommend to boot your runtimes up-front to avoid the cost of initializing
one while a request kicks in and find the pool empty, this can be easily avoided
by setting *jruby.min.runtimes* equal to *jruby.max.runtimes*. You might also
want to consider tuning the *jruby.runtime.acquire.timeout* parameter to not
wait too long when all (max) runtimes from the pool are busy.

## JRuby-Rack Configuration

JRuby-Rack can be configured by setting these key value pairs either
as context init parameters in web.xml or as VM-wide system properties.

- `rackup`: Rackup script for configuring how the Rack application is mounted.
  Required for Rack-based applications other than Rails. Can be omitted if a
  *config.ru* is included in the application root.
- `public.root`: Relative path to the location of your application's static
  assets. Defaults to */*.
- `rails.root`: Root path to the location of the Rails application files.
  Defaults to */WEB-INF*.
- `rails.env`: Specify the Rails environment to run. Defaults to 'production'.
- `rails.relative_url_append`: Specify a path to be appended to the
  `ActionController::Base.relative_url_root` after the context path. Useful
  for running a rails app from the same war as an existing app, under a
  sub-path of the main servlet context root.
- `gem.path`: Relative path to the bundled gem repository. Defaults to
  */WEB-INF/gems*.
- `jruby.compat.version`: Set to "1.8" or "1.9" to make JRuby run a specific
  version of Ruby (same as the --1.8 / --1.9 command line flags).
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
  cleared out (similar to the now deprecated `jruby.rack.ignore.env` option).
- `jruby.runtime.env.rubyopt`: This option is used for compatibility with the
  (deprecated) `jruby.rack.ignore.env` option since it cleared out the ENV after
  RUBYOPT has been processed, by setting it to true ENV['RUBYOPT'] will be kept.
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
- `jruby.rack.filter.adds.html`:
  **deprecated** use `addsHtmlToPathInfo` filter config init parameter.
  The default behavior for Rails and many other Ruby applications is to add an
  *.html* extension to the resource and attempt to handle it before serving a
  dynamic request on the original URI.
  However, this behavior may confuse other servlets in your application that
  have a wildcard mapping. Defaults to true.
- `jruby.rack.filter.verify.resource.exists`:
  **deprecated** use `verifiesHtmlResource` filter config init parameter.
  If `jruby.rack.filter.adds.html` is true, then this setting, when true, adds
  an additional check using `ServletContext#getResource` to verify that the
  *.html* resource exists. Default is false.
  (Note that apparently some servers may not implement `getResource` in the way
  that is expected here, so in that case this setting won't matter.)

## Initialization

There are often cases where you need to perform custom initialization of the
Ruby environment before booting the application. You can create a file called
*META-INF/init.rb* or *WEB-INF/init.rb* inside the war file for this purpose.
These files, if found, will be evaluated before booting the Rack environment,
allowing you to set environment variables, load scripts, etc.

For plain Rack applications, JRuby-Rack also supports a magic comment to solve
the "rackup" chicken-egg problem (you need Rack's builder loaded before loading
the *config.ru*, yet you may want to setup the gem version from within the rackup
 file). As we ship with the Rack gem bundled, otherwise when executing the
provided *config.ru* the bundled (latest) version of Rack will get loaded.

Use **rack.version** to specify the Rack gem version to be loaded before rackup :

    # encoding: UTF-8
    # rack.version: ~>1.3.6 (before code is loaded gem '~>1.3.6' will be called)

Or the equivalent of doing `bundle exec rackup ...` if you're using Bundler :

    # rack.version: bundler (requires 'bundler/setup' before loading the script)


## Logging

JRuby-Rack sets up a delegate logger for Rails that sends logging output to
`javax.servlet.ServletContext#log` by default. If you wish to use a different
logging system, configure `jruby.rack.logging` as follows:

- `servlet_context` (default): Sends log messages to the servlet context.
- `stdout`: Sends log messages to the standard output stream `System.out`.
- `slf4j`: Sends log messages to SLF4J. SLF4J configuration is left up to you,
  please refer to http://www.slf4j.org/docs.html .
- `log4j`: Sends log messages to log4J. Again, Log4J configuration is
  left up to you, consult http://logging.apache.org/log4j/ .
- `commons_logging`: Routes logs to commons-logging. You still need to configure
  an underlying logging implementation with JCL. We recommend using the logger
  library wrapper directly if possible, see http://commons.apache.org/logging/ .
- `jul`: Directs log messages via Java's core logging facilities (util.logging).

For those loggers that require a specific named logger, set it with the
`jruby.rack.logging.name` option, by default "jruby.rack" name will be used.


## Building

Checkout the JRuby-Rack code using [git](http://git-scm.com/) :

    git clone git://github.com/jruby/jruby-rack.git
    cd jruby-rack

Ensure you have [Maven](http://maven.apache.org/) installed.
It is required for downloading jar artifacts that JRuby-Rack depends on.

Build the .jar using Maven :

    mvn install

the generated jar should be located at **target/jruby-rack-*.jar**

Alternatively use Rake, e.g. to build the gem (skipping specs) :

    jruby -S rake clean gem SKIP_SPECS=true

You can **not** use JRuby-Rack with Bundler directly from the git (or http) URL
(`gem 'jruby-rack', :github => 'jruby/jruby-rack'`) since the included .jar file
is compiled and generated on-demand during the build (it would require us to
package and push the .jar every time a commit changes a source file).


## Support

Please use [github][4] to file bugs, patches and/or pull requests.
More information at the [wiki][5] or ask us at **#jruby**'s IRC channel.

[1]: https://github.com/jruby/warbler#warbler--
[2]: https://oss.sonatype.org/content/repositories/releases/org/jruby/rack/jruby-rack/
[3]: https://github.com/trinidad/trinidad
[4]: https://github.com/jruby/jruby-rack/issues
[5]: https://wiki.github.com/jruby/jruby-rack
[8]: http://badge.fury.io/rb/jruby-rack
[9]: https://secure.travis-ci.org/jruby/jruby-rack.png?branch=1.1-stable
