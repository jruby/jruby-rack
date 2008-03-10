JRuby-Rack is a lightweight adapter for the Java servlet environment that allows any Rack-based application to run unmodified in a Java servlet container. JRuby-Rack supports Rails, Merb, as well as any Rack-compatible Ruby web framework.

== Servlet Filter

- allows the servlet container to serve static content

== Goldspike-compatible Servlet

JRuby-Rack includes a stub RailsServlet and recognizes many of Goldspikes context parameters (e.g., pool size configuration), making it interchangeable with Goldspike.

- static content is served by Rack

== Rails

== Merb

== Servlet environment integration

- Servlet context is accessible to any application both through the global variable $servlet_context,
  the pre-defined constant JRuby::Rack::ServletContext, and the Rack environment variable java.servlet_context.
- Servlet request object is available in the Rack environment via the key java.servlet_request.
- Servlet request attributes are passed through to the Rack environment.
- Rack environment variables and headers can be overridden by servlet request attributes.
- Java servlet sessions are used as the default session store for both Rails and Merb.

== JRuby Runtime Management

JRuby runtime management and pooling is done automatically by the framework. In the case of Rails, runtimes are pooled. For Merb and other Rack applications, a single runtime is created and shared.