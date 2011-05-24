# JRuby-Rack

JRuby-Rack is a lightweight adapter for the Java servlet environment
that allows any Rack-based application to run unmodified in a Java
servlet container. JRuby-Rack supports Rails, Merb, as well as any
Rack-compatible Ruby web framework.

For more information on Rack, visit http://rack.rubyforge.org.

# Getting Started

The easiest way to use JRuby-Rack is to get [Warbler][1]. Warbler
depends on the latest version of JRuby-Rack and ensures it gets placed in
your WAR file when it gets built.

If you're assembling your own WAR using other means, you can install the
`jruby-rack` gem. It provides a method to locate the jruby-rack jar file:

    require 'fileutils'
    require 'jruby-rack'
    FileUtils.cp JRubyJars.jruby_rack_jar_path, '.'

Otherwise you'll need to download the [latest JRuby-Rack jar][2], drop
it into the WEB-INF/lib directory and configure the RackFilter in your
application's web.xml. Example web.xml snippets are as follows.

## For Rails

Here's sample web.xml configuration for Rails. Note the environment
and min/max runtime parameters. For multi-threaded Rails with a single
runtime, set min/max both to 1. Otherwise, define the size of the
runtime pool as you wish.

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
    </filter>
    <filter-mapping>
      <filter-name>RackFilter</filter-name>
      <url-pattern>/*</url-pattern>
    </filter-mapping>

    <listener>
      <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
    </listener>

## For Other Rack Applications

Here's a sample web.xml configuration for a Rack application. The main
difference is that JRuby-Rack looks for a "rackup" file named
`config.ru` in `WEB-INF/config.ru` or `WEB-INF/*/config.ru`.

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

If you don't have a config.ru or don't want to include it in your web
app, you can embed it in web.xml as follows (using Sinatra as an
example). Be sure to escape angle-brackets for XML!

    <context-param>
      <param-name>rackup</param-name>
      <param-value>
        require 'rubygems'
        gem 'sinatra', '~&gt; 1.0'
        require './lib/demo'
        set :run, false
        set :environment, :production
        run Sinatra::Application
      </param-value>
    </context-param>


# Features

## Servlet Filter

JRuby-Rack's main mode of operation is as a servlet filter. This
allows requests for static content to pass through and be served by
the application server. Dynamic requests only happen for URLs that
don't have a corresponding file, much like many Ruby applications
expect. The application can also be configured to dispatch through a
servlet instead of a filter if it suits your environment better.

## Servlet environment integration

- Servlet context is accessible to any application both through the
  global variable $servlet_context and the Rack environment variable
  java.servlet_context.
- Servlet request object is available in the Rack environment via the
  key java.servlet_request.
- Servlet request attributes are passed through to the Rack
  environment.
- Rack environment variables and headers can be overridden by servlet
  request attributes.
- Java servlet sessions are available as a session store for both
  Rails and Merb. Session attributes with String keys and String,
  numeric, boolean, or java object values are automatically copied to
  the servlet session for you.

## Rails

Several aspects of Rails are automatically set up for you.

- The Rails controller setting ActionController::Base.relative_url_root
  is set for you automatically according to the context root where
  your webapp is deployed.
- Rails logging output is redirected to the application server log.
- Page caching and asset directories are configured appropriately.

## JRuby Runtime Management

JRuby runtime management and pooling is done automatically by the
framework. In the case of Rails, runtimes are pooled. For Merb and
other Rack applications, a single runtime is created and shared for
every request.

## JRuby-Rack Configuration

JRuby-Rack can be configured by setting these key value pairs either
as context init parameters in web.xml or as VM-wide system properties.

- `rackup`: Rackup script for configuring how the Rack application is
  mounted. Required for Rack-based applications other than Rails or
  Merb. Can be omitted if a `config.ru` is included in the application
  root.
- `jruby.min.runtimes`: For non-threadsafe Rails applications using a
  runtime pool, specify an integer minimum number of runtimes to hold
  in the pool.
- `jruby.max.runtimes`: For non-threadsafe Rails applications, an
  integer maximum number of runtimes to keep in the pool.
- `jruby.init.serial`: When using runtime pooling, indicate that the
  runtime pool should be created serially in the foreground rather
  than spawning background threads. For environments where creating
  threads is not permitted.
- `jruby.compat.version`: Set to "1.8" or "1.9" to make JRuby run a
  specific version of Ruby.
- `public.root`: Relative path to the location of your application's
  static assets. Defaults to `/`.
- `gem.path`: Relative path to the bundled gem repository. Defaults to
  `/WEB-INF/gems`.
- `rails.root`, `merb.root`: Root path to the location of the Rails or
  Merb application files. Defaults to `/WEB-INF`.
- `rails.env`: Specify the Rails environment to run. Defaults
  to 'production'.
- `rails.relative_url_append`: Specify a path to be appended to the 
  ActionController::Base.relative_url_root after the context path. Useful
  for running a rails app from the same war as an existing app, under
  a sub-path of the main servlet context root.
- `merb.environment`: Specify the merb environment to run. Defaults to
  `production`.
- `jruby.rack.logging`: Specify the logging device to use. Defaults to
  `servlet_context`. See below.
- `jruby.rack.background.spool`: (EXPERIMENTAL) Enable large request
  bodies to be spooled to a tempfile in the background.
- `jruby.rack.filter.adds.html`: The default behavior for Rails and
  many other Ruby applications is to add an .html extension to the
  resource and attempt to handle it before serving a dynamic request
  on the original URI. However, this behavior may confuse other
  servlets in your application that have a wildcard mapping. Defaults
  to true.
- `jruby.rack.filter.verify.resource.exists`: If
  `jruby.rack.filter.adds.html` is true, then this setting, when true,
  adds an additional check using `ServletContext#getResource` to
  verify that the .html resource exists. Default is false. (Note that
  apparently some servers may not implement `getResource` in the way
  that is expected here, so in that case this setting won't matter.)
- `jruby.rack.ignore.env`: Clears out the ENV hash in each runtime to
  insulate the application from the environment.

## Initialization

There are often cases where you need to perform custom initialization
of the Ruby environment before booting the application. You can create
a file called `META-INF/init.rb` or `WEB-INF/init.rb` inside the war
file for this purpose. These files, if found, will be evaluated before
booting the Rack environment, allowing you to set environment
variables, load scripts, etc.

## Logging

JRuby-Rack sets up a delegate logger for Rails that sends logging
output to `javax.servlet.ServletContext#log` by default. If you wish
to use a different logging system, configure `jruby.rack.logging` as
follows:

- `servlet_context` (default): Sends log messages to the servlet
  context.
- `stdout`: Sends log messages to the standard output stream
  `System.out`.
- `commons_logging`: Sends log messages to Apache commons-logging. You
  still need to configure commons-logging with additional details.
- `slf4j`: Sends log messages to SLF4J. Again, SLF4J configuration is
  left up to you.
- `log4j`: Sends log messages to log4J. Again, log4J configuration is
  left up to you.

For those loggers that require a specific named logger, set it in the
`jruby.rack.logging.name` option.

# Building

Checkout the JRuby Rack code and cd to that directory.

    git clone git://github.com/nicksieger/jruby-rack.git
    cd jruby-rack

You can choose to build with either Maven or Rake. Either of the
following two will suffice (but see the NOTE below).

    mvn install
    jruby -S rake

The generated jar should be located here: target/jruby-rack-*.jar.

# Issues

Please use GitHub to file bugs, patches and pull requests.

- https://github.com/nicksieger/jruby-rack
- https://github.com/nicksieger/jruby-rack/issues

## Rails Step-by-step

This example shows how to create and deploy a simple Rails app using
the embedded Java database H2 to a WAR using Warble and JRuby Rack.

Install Rails and the driver and ActiveRecord adapters for the H2
database:

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

Generate a scaffold for a simple model of blog comments.

    jruby script/rails generate scaffold comment name:string body:text

Run the database migration that was just created as part of the scaffold.

    jruby -S rake db:migrate

Start your application on the Rails default port 3000 using WEBrick
and make sure it works:

    jruby script/rails server

Generate a custom Warbler WAR configuration for the blog application

    jruby -S warble config

Generate a production version of the H2 database for the blog
application:

    RAILS_ENV=production jruby -S rake db:migrate

Edit this file: config/warble.rb and add the following line after
these comments:

    # Additional files/directories to include, above those in config.dirs
    # config.includes = FileList["db"]
    config.includes = FileList["db/production_h2*"]

This will tell Warble to include the just initialized production H2
database in the WAR.

Continue editing config/warble.rb and add the following line after
these comments:

    # Gems to be packaged in the webapp.  Note that Rails gems are added to this
    # list if vendor/rails is not present, so be sure to include rails if you
    # overwrite the value
    # config.gems = ["activerecord-jdbc-adapter", "jruby-openssl"]
    # config.gems << "tzinfo"
    # config.gems["rails"] = "1.2.3"
    config.gems << "activerecord-jdbch2-adapter"

This will tell Warble to add the JDBC driver for H2 as well as the
ActiveRecord JDBC and JDBC-H2 adapter Gems.

Now generate the WAR file:

    jruby -S warble war

This task generates the file: blog.war at the top level of the
application as well as an exploded version of the war located here:
tmp/war.

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
