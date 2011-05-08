require 'rack/handler/servlet'

# Rack handler for an embedded jetty server
module Rack::Handler::Jetty

  def self.run(app, options)
    begin
      include_class 'javax.servlet.http.HttpServlet'
      include_class 'org.mortbay.log.Log'
      include_class 'org.mortbay.jetty.Server'
      include_class 'org.mortbay.jetty.servlet.Context'
      include_class 'org.mortbay.jetty.servlet.ServletHolder'
      include_class 'org.jruby.rack.servlet.ServletRackContext'
      include_class 'org.mortbay.jetty.handler.ResourceHandler'
      include_class 'org.mortbay.jetty.handler.DefaultHandler'
      include_class 'org.mortbay.jetty.handler.HandlerList'
      include_class 'org.mortbay.jetty.handler.ContextHandlerCollection'
      include_class 'org.mortbay.jetty.servlet.DefaultServlet'
    rescue
      $stderr.puts(msg = "Unable to load java classes: #{$!}")
      raise msg
    end

    # these need to be here so they are after all the java code is brought in
    require 'rack/handler/servlet'
    require 'msp/rack_jetty/filter'
    require 'msp/rack_jetty/log_adapter'

    jetty = org.mortbay.jetty.Server.new options[:Port]
    context_path = options[:context_path] || "/"
    context = org.mortbay.jetty.servlet.Context.new(nil, context_path,
      org.mortbay.jetty.servlet.Context::NO_SESSIONS)

    servlet_pattern = options[:servlet_pattern] || "/*"

    # The filter acts as the entry point in to the application
    context.add_filter(
      filter_holder(app, nil, options[:static_env]), 
      servlet_pattern, 
      org.mortbay.jetty.Handler::ALL
    )

    # FIXME Umm, this might be wrong
    context.set_resource_base(File.dirname(__FILE__))

    # if we don't have at least one servlet, the filter gets nothing
    context.add_servlet(org.mortbay.jetty.servlet.ServletHolder.new(
      org.mortbay.jetty.servlet.DefaultServlet.new), servlet_pattern)

    jetty.set_handler(context)
    jetty.start
    jetty.join
  end

  def self.filter_holder(app, logger, static_env)
    org.mortbay.jetty.servlet.FilterHolder.new(
      MSP::RackJetty::Filter.new(app, logger, static_env))
  end

end
