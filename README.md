# JRuby-Rack

JRuby-Rack is a lightweight adapter for the Java servlet environment that allows 
any Rack-based application to run unmodified in a Java servlet container. 
JRuby-Rack supports Rails as well as any Rack-compatible Ruby web framework.

For more information on Rack, visit http://rack.rubyforge.org.

[![Build Status](https://secure.travis-ci.org/jruby/jruby-rack.png?branch=master)](http://travis-ci.org/jruby/jruby-rack)

# Getting Started

The easiest way to use JRuby-Rack is to get [Warbler][1]. 
Warbler depends on the latest version of JRuby-Rack and ensures it gets placed 
in your WAR file when it gets built.

If you're assembling your own WAR using other means, you can install the
**jruby-rack** gem. It provides a method to locate the jar file:

    require 'fileutils'
    require 'jruby-rack'
    FileUtils.cp JRubyJars.jruby_rack_jar_path, '.'

Otherwise you'll need to download the [latest jar release][2], drop it into the 
*WEB-INF/lib* directory and configure the RackFilter in your application's 
*web.xml*. Example web.xml snippets are as follows.

## For Rails

Here's sample web.xml configuration for Rails. Note the environment and min/max 
runtime parameters. For multi-threaded Rails with a single runtime, set min/max 
both to 1. Otherwise, define the size of the runtime pool as you wish.

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

## For Other Rack Applications

Here's a sample web.xml configuration for a Rack application. The main difference 
is that JRuby-Rack looks for a "rackup" file named **config.ru** in 
`WEB-INF/config.ru` or `WEB-INF/*/config.ru`.

    <filter>
      <filter-name>RackFilter</filter-name>
      <filter-class>org.jruby.rack.RackFilter</filter-class>
    </filter>
    <filter-mapping>
      <filter-name>RackFilter</filter-name>
      <url-pattern>/*</url-pattern>
    </filter-mapping>

    <listener>
      <listener-class>org.jruby.rack.RackServletContextListener</listener-class>
    </listener>

If you don't have a config.ru or don't want to include it in your web app, you 
can embed it in web.xml as follows (using Sinatra as an example). 

Be sure to escape angle-brackets for XML !

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


# Features

## Servlet Filter

JRuby-Rack's main mode of operation is as a servlet filter. This allows requests 
for static content to pass through and be served by the application server. 
Dynamic requests only happen for URLs that don't have a corresponding file, much 
like many Ruby applications expect. 
The application can also be configured to dispatch through a servlet instead of 
a filter if it suits your environment better.

## Servlet environment integration

- Servlet context is accessible to any application through the Rack environment 
  variable *java.servlet_context* as well as the `$servlet_context` global.
- Servlet request object is available in the Rack environment via the
  key *java.servlet_request*.
- Servlet request attributes are passed through to the Rack environment.
- Rack environment variables and headers can be overridden by servlet
  request attributes.
- Java servlet sessions are available as a session store for Rails. 
  Session attributes with String keys and String, numeric, boolean, or java 
  object values are automatically copied to the servlet session for you.

## Rails

Several aspects of Rails are automatically set up for you.

- The Rails controller setting `ActionController::Base.relative_url_root`
  is set for you automatically according to the context root where
  your webapp is deployed.
- `Rails.logger` output is redirected to the application server log.
- Page caching and asset directories are configured appropriately.

## JRuby Runtime Management

JRuby runtime management and pooling is done automatically by the framework. 
In the case of Rails, runtimes are pooled by default (the default will most 
likely change with the adoption of Rails 4.0). For other Rack applications a 
single shared runtime is created and shared for every request by default (as of 
**1.1.8** if *jruby.min.runtimes*/*jruby.max.runtimes* values are specified 
pooling is supported as well).

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
- `jruby.rack.logging`: Specify the logging device to use. Defaults to
  `servlet_context`. See below.
- `jruby.rack.ignore.env`: Clears out the `ENV` hash in each runtime to insulate 
  the application from the environment.
- `jruby.rack.request.size.initial.bytes`: Initial size for request body memory 
   buffer, see also `jruby.rack.request.size.maximum.bytes` bellow.
- `jruby.rack.request.size.maximum.bytes`: The maximum size for the request in
   memory buffer, if the body is larger than this it gets spooled to a tempfile.
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

# Building

Checkout the JRuby Rack code and cd to that directory.

    git clone git://github.com/jruby/jruby-rack.git
    cd jruby-rack

Ensure you have Maven installed. It is required for downloading jar
artifacts that JRuby-Rack depends on.

You can choose to build with either Maven or Rake. Either of the
following two will suffice.

    mvn install
    jruby -S rake

The generated jar should be located here: target/jruby-rack-*.jar.

# Issues

Please use GitHub to file bugs, patches and pull requests.

- https://github.com/jruby/jruby-rack
- https://github.com/jruby/jruby-rack/issues

# Releases

For JRuby-Rack contributors, the release process goes something like
the following:

1. Ensure that release version is correct in _pom.xml_ and `mvn install`
   runs clean.
2. Ensure generated changes to _src/main/ruby/jruby/rack/version.rb_ are
   checked in.
3. Ensure _History.txt_ is updated with latest release information.
3. Tag current release in git: `git tag <version>`.
4. Push commits and tag: `git push origin master --tags`
5. Build gem: `rake clean gem`
6. Push gem: `gem push target/jruby-rack-*.gem`
7. Release jar to maven repository: `mvn -DupdateReleaseInfo=true deploy`
8. Bump the version in _pom.xml_ to next release version *X.X.X.dev-SNAPSHOT*, 
   run `mvn install`, and commit the changes.

## Rails Step-by-step

This example shows how to create and deploy a simple Rails app using
the embedded Java database H2 to a WAR using Warbler and JRuby-Rack.

Install Rails and the ActiveRecord adapters + driver for the H2 database:

    jruby -S gem install rails activerecord-jdbch2-adapter

Install Warbler:

    jruby -S gem install warbler

Make the "Blog" application

    jruby -S rails new blog
    cd blog

Copy this configuration into config/database.yml:

    development:
      adapter: jdbch2
      database: db/development_h2_database

    test:
      adapter: jdbch2
      database: db/test_h2_database

    production:
      adapter: jdbch2
      database: db/production_h2_database

Add the following to your application's Gemfile:

    gem 'activerecord-jdbch2-adapter', :platform => :jruby

Generate a scaffold for a simple model of blog comments.

    jruby script/rails generate scaffold comment name:string body:text

Run the database migration that was just created as part of the scaffold.

    jruby -S rake db:migrate

Start your application on 3000 using WEBrick and make sure it works:

    jruby script/rails server

Generate a production version of the H2 database for the application:

    RAILS_ENV=production jruby -S rake db:migrate

Generate a custom Warbler WAR configuration for the blog application

    jruby -S warble config

Edit *config/warble.rb* and add the following line after these comments:

    # Additional files/directories to include, above those in config.dirs
    # config.includes = FileList["db"]
    config.includes = FileList["db/production_h2*"]

This will tell Warbler to include the just initialized production H2
database in the WAR.

Now generate the WAR file:

    jruby -S warble war

This task generates the file: blog.war at the top level of the application as 
well as an exploded version of the war located at *tmp/war*.

The war should be ready to deploy to your Java application server.

# Thanks

- All contributors! But also:
- Dudley Flanders, for the Merb support
- Robert Egglestone, for the original JRuby servlet integration
  project, Goldspike
- Chris Neukirchen, for Rack
- Sun Microsystems, for early project support
- Engine Yard, for more recent support

[1]: http://caldersphere.rubyforge.org/warbler
[2]: http://repository.codehaus.org/org/jruby/rack/jruby-rack/
