## 1.1.20 (22/01/16)

- pre-maturely avoid Ruby frozen string literals coming at us ... ''.dup meh!
- allow to boot when RAILS_ROOT/public directory does not exist (closes #197)
- for better booter detection - export public path after working dir was changed
- `ActionController::Base` provides a method `servlet_response` to return the
  `java.servlet_response` rack env (#201)
- adjust jruby home dir fallback (for default $LOAD_PATH) correctly on 9K and --2.0
- servlet env should behave on `fetch` and `[]` like a Hash (nil value can be set)

## 1.1.19 (01/07/15)

- update (bundled) rack to 1.5.5
- servlet attrs with null/false values should not end up with an '' env value (#195)
- tune ErrorApp + ShowStatus to respect set 'rack.showstatus.detail' (#194)
- allow for more `JRuby::Rack::ErrorApp` customizations + retrieve cause when needed

## 1.1.18 (13/01/15)

- back-port Rack::ShowStatus to be used with out ErrorApp (contains XSS fix #190)
- search rackup (config.ru) on context-classloader if not found elsewhere
- introduce a new ClassPathLayout where the whole app + gems are on CP (#191)
- update to (vendored) rack ~> 1.5.2 (for JRuby-Rack 1.1.x)
- use Rack::Utils.best_q_match in ErrorApp if available
- improved rack-compatibility for our "pure" servlet-env request env parsing
  * raise a TypeError just like rack does when it detects invalid parameters
  * compatibility with rack's parse_nested_query logic

## 1.1.17 (30/12/14)

This release changes deployment from codehaus.org to oss.sonatype.org for artifacts.

- just keep the jruby-home when set by jruby to "uri:classsloader:..." JRuby 9k
- support configuration of `Response.swallow_client_abort?` (#186)
- better client EOF (socket abort "Broken pipe") detection in Response
  we're now "officially" handling Jetty and maybe a bunch of others
- allow PATCH verb to be processed by the ruby application (#184)

## 1.1.16 (14/08/14)

- deal with `real_path` (file-system) layout regression introduced in 1.1.15

Changes from 1.1.15 apply since the previous release got yanked due a regression.

## 1.1.15 (ya/nk/ed)

- deal with potential getParameterMap "bugs" - null values e.g. on Jetty 6 (#154)
- support filter init-param to configure whether response is handled "by default"
- no header or status set (on response capture) - should report as handled
  works with Tomcat as before and serves static content with Jetty (#175)
- make sure internal servlet attributes are retrieved on `env[]` (#173)
- using our "servlet-specific" path methods in booter - we're avoiding
  `File.exist?` and expanding path specifically for the application layout
  this helps for a better boot in non-expanded .war scenarios
- improve app layout dir resolution - e.g. FS public path should resolve relative
- a work-around for WAS (8.5) failing on `Dir.chdir` while booting (#170)
- consider response unhandled when OPTIONS with "Allow" header set (#153)
- improved handling for jruby.compat.version (should work with jruby-head)
- start using de.saumya.mojo jruby plugins for mvn (relates to #108 as well)
  this allows us to work without a GEM_HOME/GEM_PATH (local ruby install)
- use ruby-style methods for the servlet api (in our servlet_env handler)

## 1.1.14 (24/02/14)

- re-invent the ErrorApp without Rack::File and with support for 503(.html)
- when jruby.rack.error.app is set - make sure it's actually used (fixes #166)
- review Railtie for setting relative_url_root - do not override if already set
- support setting a "relative url root" even with plain rack applications for
  now needs to be explicitly configured with rack.relative_url_root_variable
- honor the set `config.log_formatter` when setting up logger in Rails
- when a header is added response should be considered handled (#153)
- support for returning managed applications from rack factory decorators
  using `RackApplicationFactoryDecorator.getManagedApplications`
- use .equals() rather than == since the level string is not always the same
  object instance as defined by the RackLogger interface
- support (building) `rake gem` on RubyGems 2.0 (removed Gem::Builder)
- rack 1.5.x support for 'our' servlet session store (with backwards-compat)

## 1.1.13.3 (13/11/13)

- restore compatibility with JRuby < 1.6.7

## 1.1.13.2 (02/04/13)

- fix warning in Rack::Utils::Response#write_headers
- bundle latest Rack 1.4 (1.4.5)

## 1.1.13.1 (14/01/13)

- fix missing explicit require 'jruby/rack/version' in 1.1.13

## 1.1.13 (13/01/13)

- make sure (body) Java channel is always closed on Response#write_body
- deal with capture backtrace incompatibility on JRuby 1.7 (#139)
- bundle (latest) rack 1.4.2
- make sure out custom (env) Hash sub-classes behave more Hash-y (#134)
- support for setting a custom JRuby-Rack Response class (e.g. due `send_file`)
- explicit support for sending file bodies with the possibility to re-define
  `send_file` per app-server
- make sure we still maintain 2.3 compatibility (fix for #138)
- fix send_file not being able to handle large > 2GB files (#133)
- review chunked support - changed default behavior into patching Rack::Chunked
  the old behavior still works by setting jruby.rack.response.chunked = true
- handle empty (null) strings when parsing (Ruby) magic comments e.g. config.ru
- versioning review - make sure versions are always "valid" even for SNAPSHOTs

## 1.1.12 (28/11/12)

- make (Default)Env to be the environment Hash instance itself since we need
  to handle custom lazy-bound keys but can not use a default proc (#132)
- support the renew (and skip) session option with servlet store (#131)
- improve ENV isolation with booted Ruby runtimes
  * jruby.rack.env replaces jruby.rack.ignore.env (now deprecated)
  * make sure RUBYOPT is ignored (with backwards compat)
  * jruby.rack.env.rubyopt for finer RUBYOPT behavior control
  * allow env value to be specified from config
- solve the rackup "chicken - egg" problem with a plain Rack app
  * with a magic comment in config.ru # rack.version: ~>1.3.6
  * for bundle exec "emulation" use # rack.version: bundler
- (temporarily) introduce RackEnvironment.ToIO to avoid instance vars
  on non-persistent Java types (JRuby 1.7 warning)
- add a JRuby::Rack::Helpers module for helper functions
- decorating factories (e.g. pooling factory) can now be distinguished
- refactored / updated error handling :
  * move the decision about throwing the init error into the listener
  * unify exception handling across decorating app factories with support
    for configuring exception handling with the *jruby.rack.error* option
  * make sure init errors are thrown from pooling factory's init
  * added an ErrorApplication marker interface
  * dispatcher might now decide what status to return (or throw)
- let the servlet container deal with null response header values
- expose the rack context using JRuby::Rack.context= in embed scenario
- rely less on booter and $servlet_context whenever possible
  * moved Booter#logger into JRuby::Rack.logger
  * boot! now 'exports' JRuby::Rack.app_path and public_path
  * changed $servlet_context refs to JRuby::Rack.context
- maven + rake (joint) build review
  run mvn compile on rake compile instead of custom javac
  (+ updated jruby.version to 1.6.8)
- removed LoggerConfigurationException used with Commons-Logging
- fix invalid /tmp detected jruby home LOAD_PATH on 1.7.0
- support setting compat version 2.0 (on JRuby 1.7.x)
- application layout (JRuby::Rack::AppLayout) improvements :
  * introduce app.root context param (similar to rails.root)
  * RailsWebInfLayout is now the same as WebInfLayout
  * added (generic) FileSystemLayout (handles rails apps as well)
  * RailsFilesystemLayout is FileSystemLayout for compatibility
  * make sure paths are expanded when using a FS layout
  * moved change_working_directory code to happen within Booter
  * fix Booter failing to boot! when layout.gem_path nil (or empty)
- Rails booter's RAILS_ENV should default to RACK_ENV if set
- make sure original rack body gets always closed with optimized send_file
  might lead to side-effects such as not releasing database connections (#123)
- some more useful Servlet API Ruby extensions ('attribute' managing objects
  such as ServletContext behave similar to Hash)

## 1.1.10 (04/09/12)

- correctly dechunk data from response and handle flushing,
  finally Rails 3.1+ `render stream: true` support (#117)
- initial compatibility with Rails master (getting torwards 4.0.0.beta)
  known issues: ActionController::Live seems to end up with a dead-lock
- ServletEnv now parses cookies using HttpServletRequest.getCookies instead of
  leaving it off for Rack::Request

## 1.1.9 (19/08/12)

- rack env regression fix when used with rack-cache, introduced in 1.1.8 (#116)
  request.env should work correctly when (duped and) frozen

## 1.1.8 (17/08/12)

- introduced ServletEnv for cases when it's desirable to fully use the servlet
  environment to create the rack env (and not let Rack::Request parse params
  but rely on the parameters already parsed and available from the servlet
  request #110). this is an experimental feature that might change in the
  future and requires setting 'jruby.rack.handler.env' param to 'servlet' !
- separated out Env (LazyEnv) into a separate file :
  * Env got refactored into DefaultEnv (with lazyness built-in)
  * LazyEnv got removed as it is not longer necessary
  * Rack::Handler::Servlet.env sets the used env conversion class
- introduce a generic getNumberProperty on RackConfig
- introduce a base RackException and add a custom AcquireTimeoutException for
  pool timeouts (related to jruby.runtime.acquire.timeout parameter)
- RackInitializationException changed to unchecked as it inherits from
  RackException now
- PoolingRackApplication (and related) polishing :
  * avoid creating a new application from getApplication when a permit is
    granted but pool is empty
  * support to wait till pool becomes ready by default otherwise wait until
    initial application objects are present in the pool before returning
    (controlled with the jruby.runtime.init.wait accepting true/false/integer)
  * edge case handling where (in case were set to not wait for initialization)
    we should wait for an initializer thread to put an application into the pool
  * allow acquire timeout (jruby.runtime.acquire.timeout param) to be specified
    as a decimal number for finer control and decreased the timeout default
    from 30s to 10s (although seems still too high for a default)
- jruby runtime pooling for plain Rack applications (not just Rails)

## 1.1.7 (21/06/12)

- support for delegating logs to java.util.logging (jruby.rack.logging: JUL)
- extend RackLogger with levels for better logging with underlying log impl
- consider 405 as an unhandled response from filter chain by default (#109)
- make sure optimized file streaming gets used with rails send_file, this serves
  as a work-around for a --1.9 bug in jruby-1.6.7 with string encoding (#107)

## 1.1.6 (16/05/12)

- consider 403 as an unhandled response from filter chain (along with 404) and
  allow configuring responseNotHandledStatuses via filter init parameter (#105)

## 1.1.5 (04/03/12)

- bundler 1.1 workaround when ENV is cleared - set ENV['PATH'] = ''
- resolve servlet context from request.getServletContext if posssible
- resetUnhandledResponse init param for controlling chain response handling
- filter specific context params deprecated in favor of filter init params
- logging should not depend on $servlet_context global (better #88 fix)
- cleanup request buffer /tmp files after input stream gets closed
- add an embed Config to correctly setup RackConfig from ruby runtime
- introduce RackConfig#getOut/getErr for possible 1/2 stream redirection
- ensure ENV changes do not affect the native environment (#101)
- change Rails.public_path early on (#99) and do not set PUBLIC_ROOT in 3.x
- synchronize session operations with JavaServletStore (#95)
- allow configuring request buffer initial/maximum size using parameters
- initialization exception behavior in listener might be overriden (#16)

## 1.1.4 (02/21/12)

- incorrectly interpreted byte in RewindableInputStream causing EOFs (#92)
- fix JRuby::Rack::Response 1.9 incompatibility due String#each
- ensure $servlet_context is not nil in embedded scenario (#88)
- upgrade to Rack 1.4.1
- fix resolving rackup on WLS 10.3 with Rails 3
- explicit require rack + on rails allow bundler to decide rack version
- config.logger fixes and support for ActiveSupport::TaggedLogging (#93)
- revert regression in 1.1.3 with incorrect filter behavior (#84)

## 1.1.3 (01/10/12)

- Additional fix for #73, #76 (Fix relative_url_root issue for good)
- Stop using BufferedLogger (#80)

## 1.1.2 (12/30/11)

- GH#18: Undefined method `call' for nil:NilClass
- GH#44: JRuby-rack POST form-urlencoded doesn't work with Jetty
- GH#71: request.body.read stopped working
- GH#73, GH#76: relative_url_root= called for rails > 3
- GH#79: FileNotFoundException on WAS 8.0

## 1.1.1 (11/11/11)

- Support for embedding a web server using a Rack::Handler
  Servlet/Filter
- Use bundler/maven for project's dependency management
- 1.9 $LOAD_PATH fix when jruby.home is set to /tmp
- Fix /config.ru resource loading on AppEngine
- Support for passing arguments to runtimes via
  jruby.runtime.arguments
- JavaServletStore rewrite based upon Rack::Session::Abstract::ID
- Upgrade to Rack 1.3.5

## 1.0.10 (08/24/11)

- Bugfix release for Rails 3.1
- Upgrade to Rack 1.3.2

## 1.0.9 (05/24/11)

- Bugfix release for Trinidad 1.2.x
- GH#27: Deal with incompatible signature change between JRuby 1.5.6
  and 1.6.
- Properly convert URLs to files for __FILE__ binding when evaluating
  init.rb (Ketan Padegaonkar)

## 1.0.8 (03/21/11)

- Add a check for /config.ru if not found in /WEB-INF (for appengine gem)
- Modify LocalContext to support minimal LocalConfig for JMS (Garret Conaty)
- JRUBY-5573: Add support for log4j
- Process RUBYOPT variable if it's set
- Change application factory to use ScriptingContainer API for
  creating runtimes
- Upgrade to Rack 1.2.2
- GH#21: Implement RackInput#size

## 1.0.7 (03/04/11)

- JRUBY_RACK-36: Always set env['HTTPS'] according to request.getScheme
- GH#10: Add `jruby.rack.ignore.env` property which clears out the ENV
  hash in each runtime to insulate the application from the environment.
- GH#12: Another fix to suppress client abort exceptions
- GH#14: Remove trailing slash from jruby.home
- GH#15: Fix infinite redirect issue with Winstone
- GH#17: __FILE__ constant inside config.ru is not absolute

## 1.0.6 (01/20/11)

- GH#4: Related to JRUBY-5281 and spaces in the path. Copy jruby.home
  fix here also. Fixes "no such file to load" LoadErrors for lots of
  cases.
- NOTE: Next release will remove this code from JRuby-Rack completely,
  relying on JRuby to properly determine jruby.home.
- GH#8: Allow DefaultRackApplicationFactory to use an existing, single
  runtime. (David Calavera)
- GH#9: Support chunked Transfer-Encoding, allowing for early flush of
  the output (Alejandro Crosa)
- Add some new options for handling the Rack body.
  * If the body object responds to `#call`, then the servlet output
    stream will be yielded to it.
  * If the body object responds to `#to_channel`, then JRuby-Rack will
    copy the channel to the output stream for you. The same happens if
    the body responds to `#to_inputstream`.
  * Otherwise, JRuby-Rack follows the standard Rack behavior of
    calling `#each` on the body and copying the contents to the output
    stream.
- GH#7: JavaServletStore: Add missing #exists? and #destroy
  implementations
- JRUBY_RACK-38: Don't needlessly raise errors because of client abort
  exceptions
- GH#5: Experimental background spooling enabled by
  `jruby.rack.background.spool` context parameter
- JRUBY_RACK-39: Proper routing of / => /index.html (if it exists).
  New config properties `jruby.rack.filter.adds.html` and
  `jruby.rack.filter.verify.resource.exists` to tweak this behavior.
- Improved error and environment capture when something goes wrong,
  e.g., `no such file to load` errors. Now a status dump will be put
  in the server log. In the future, we may hook up a remote bug
  submission capture process.
- Add env['SERVER_SOFTWARE'] to Rack environment.
- Hack around Bundler bug #1033

## 1.0.5 (01/11/11)

- GH#6: Add context-init parameter `jruby.compat.version` which can be
  set to either `1.8` or `1.9` to start JRuby in the corresponding
  Ruby version.
- Changes to rackup evaluation to help debugging: Set rackup filename
  when executing config.ru, use a ; instead of \n when evaluating
  rackup code

## 1.0.4

- Make sane defaults for app/gem/public paths when using
  RailsFilesystemLayout (Kristian Meier)
- Add 'jruby.rack.slash.index' init param that forces / =>
  /index.html. Fixes JRUBY_RACK-35 and makes Jetty 6 work without
  having to configure dirAllowed in Jetty's default servlet.
- Switch to mostly relying on request URI and not so much servlet
  path/path info. Makes Tomcat 7 work.
- Added rails.relative_url_append context parameter. This can be set in
  your web.xml or similar to append a string to the end of the context
  path when the RAILS_RELATIVE_URL_ROOT is set. This allows you to
  host your rails app in a location other than the base context path
  of your application. (Ben Rosenblum)
- Don't use toURI, following changes in JRuby 1.5.6.

## 1.0.3

- JRUBY-4892: Fix IO collapsing \r\n to \n on Windows
- Fix setting of relative_url_root in Rails 3
- Recognize META-INF/init.rb and WEB-INF/init.rb as init scripts.

## 1.0.2

- Upgrade to Rack 1.2.1 (required for Rails 3 RC)
- Retain any GEM_PATH that's set in the environment
- Fixed XML Schema Location definition for jsptaglib for JBoss 6
  (NAKAMURA Hiroshi)
- JRUBY_RACK-33: Fix RackFilter to only append .html to path info if
  the resource exists (thanks Patrick Cheng)

## 1.0.1

- 1.0.0 release had a packaging snafu. Too many releases in too short a timespan

## 1.0.0

- Might as well go to 1.0. We've been used in production code for a
  while now.
- Turns out the LoadError path dumping is pretty annoying. Rearrange
  the code and have it only activated by 'jruby.rack.debug.load'.

## 0.9.9

- 0.9.8 broke Rubygem's custom require

## 0.9.8

- Look for config.ru in either WEB-INF/config.ru or
  WEB-INF/*/config.ru and use it for racking up the application.
  'rackup' context parameter is still supported for embedding in
  web.xml too.
- JRUBY_RACK-21: Add logging adapter classes for commons-logging and
  slf4j. If you use either of these logging frameworks in your app,
  simply set 'jruby.rack.logging' to 'clogging' or 'slf4j' in either
  web.xml as a context parameter or as a system property to pipe Ruby
  logs through those frameworks (h/t jcantrill).
- Fix bug with RackRewindableInput#read(N) -- should return nil when finished
- Fix Rails 3 logger configuration
- Only load vendor/rack if Rack is not already loaded

## 0.9.7

- Rails 3 support
- Fix "overrides final method getRuntime" error due to 1.5 Java class
  generation changes
- Upgrade to Rack 1.1.0
- Upgrade to servlet 2.5 and jsp 2.1
- Fix SCRIPT_NAME/PATH_INFO overlap issue with context paths (seen on
  GAE and elsewhere)
- JRUBY_RACK-8:  adjust LOAD_PATH if jruby_home detection failed in the current environment
- JRUBY_RACK-23: JavaServletStore needs to be required before it can be set as the session store
- JRUBY_RACK-26: Rack crashes on multipart/form-data bodies submitted with curl (or other headless client)
- JRUBY_RACK-27: Rails.public_path has a trailing /
- JRUBY_RACK-29: Incorrectly Bundling jruby-rack-0.0.7.SNAPSHOT.jar
- JRUBY_RACK-19: Add a jruby-rack gem for finding the jar file
- JRUBY_RACK-24: Support non-war deployment of Rails apps

## 0.9.6

- JRUBY_RACK-22: Ensure we call #close on the body per the Rack spec.
- Set jruby.management.enabled true when creating a runtime. JRuby 1.5
  will default this flag to false, but you probably still want JMX
  capability inside an appserver.
- Miscellaneous spec cleanup due to changes in JRuby 1.5

## 0.9.5

- Upgrade to Rack 1.0.0. However, if you supply Rack in your
  application (either via rubygems or by vendoring it), it will take
  precedence -- JRuby-Rack's bundled copy is only loaded as a
  fallback. This allows you to upgrade Rack without having to wait for
  a new JRuby-Rack release.
- Implement Rack-based java servlet session mechanism. You'll have to
  turn on java servlet sessions by setting
    ActionController::Base.session_store = :java_servlet_store
  in your config/initializers/session_store.rb.
- JRUBY_RACK-7: Implement a rewindable 'rack.input' shim between the
  servlet input stream and the Rack environment. Below a certain
  byte-size threshold, the input is entirely buffered in memory. Above
  the threshold, the input is written to a tempfile. The default
  threshold is 64k, and can be controlled by the system property
  'jruby.rack.request.size.threshold.bytes'.
- The previous non-rewindable input behavior can be re-instated by
  setting the system property 'jruby.rack.input.rewindable' to false.
  Despite being out of spec, environments such as Google AppEngine
  require this behavior because writing to a tempfile is not possible.
- JRUBY_RACK-4: deal with threading and to_io by assigning IO object
  to an instance variable instead of defining a singleton method on
  the metaclass/singleton class
- JRUBY_RACK-17: Fix SCRIPT_NAME/PATH_INFO in root context (Chris
  Read)
- JRUBY_RACK-10, JRUBY_RACK-15: Fix request channel read issue w/
  POSTs and multiparts (Michael Pitman, Lenny Marks)
- JRUBY_RACK-14: Override both Servlet service methods (Michael
  Pitman)

## 0.9.4

- PLEASE NOTE: Prior to 0.9.4, jruby-rack would try to use the java
  servlet session store by default. This caused more confusion than
  it's worth; so the default Rails cookie session store has been
  reinstated for this release.
- Upgrade bundled Rack version to 0.9.1
- Introduce RackLogger, defaults to log to servlet context but can be
  made to point to stdout by setting -Djruby.rack.logging=stdout (for
  Google AppEngine)
- Detect Rails 2.3 rack machinery and dispatch to it rather than the
  legacy CGI shim.
- TODO: Still missing a java servlet Rack::Session adapter for Rails
  2.3. Should have it for next release.
- Update example Rails application to Rails 2.3.2, include bits for
  deployment to Google AppEngine using Warbler.
- RackApplication-related core Java classes have been insulated from
  the servlet API, so that (parts of) JRuby-Rack can be used outside
  of a servlet container. If your application or library is coupled to
  these classes, you'll likely be broken with this release. See Nick
  for details.
- Fix TLD to be more compatible (Fred McHale).
- Switched main code repository to kenai.com. Github.com still
  available as a mirror and for forking.
- EXPERIMENTAL: Beginnings of a JMS API (more details to come)
- REMOVAL: All the goldspike compatibility bits have been removed. You
  should upgrade your application to use a web.xml similar to what
  comes with Warbler.

## 0.9.3

- Merb updates for 1.0 compatibility
- Patch race condition in runtime pooling that allowed more than max
  number of runtimes
- Fix bug with backref interpretation and windows paths
- JRUBY-2908: Add fallback for when servletContext.getRealPath doesn't
  work (Joern Hartmann)
- Add extra prevention to ensure that IO descriptor keys do not leak in
  the runtime's cache of descriptors (see also JRUBY-3185)
- Switched to dual rake/maven build process
- Switched main code repository to github (for now)

## 0.9.2

- Upgrade to Rack 0.4.0
- Only chdir at startup when the /WEB-INF directory exists (fix for jetty-rails)
- Fix typos in rails tag tld
- Add getRuntime to RackApplication for use by non-web embedded applications
- Use a shared application factory for Rails if max runtimes ## 1 (to support multi-threaded Rails)
- Change from jruby.initial.runtimes to jruby.min.runtimes to be consistent w/ Warbler

## 0.9.1

- Change each runtime's notion of current directory to /WEB-INF, so you can do
  loads and requires relative to WEB-INF
- JRUBY-2507: Update Rails boot override to not pre-load action_controller
- Don't assume or set cache_template_loading to true, rely on Rails to do it for us
- Set ENV['HTTPS'] = 'on' for Rails depending on servlet request scheme (Lenny Marks)
- Fix request URI -- must include query string
- Updated to be built and tested against JRuby 1.1.3
- Ensure that gem environment is set up for plain rack apps too
- JRUBY-2594: Fix URI-escaping issue (e.g., when spaces are in the path)
- Make use of 'Rails.public_path' in Rails 2.1
- JRUBY-2620: Fix issue with non-string headers
- Support integer and date headers directly
- Examples: Rails updated to 2.1, Camping and Sinatra examples added/working

## 0.9

- First public release.
