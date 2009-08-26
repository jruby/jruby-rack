class SnoopController < ApplicationController
  def index
    @snoop = {}
    @snoop[:env]               = request.env
    @snoop[:remote_addr]       = request.remote_addr
    @snoop[:remote_ip]         = request.remote_ip
    @snoop[:host_with_port]    = request.host_with_port
    @snoop[:path]              = request.path
    @snoop[:server_software]   = request.server_software
    @snoop[:cookies]           = request.cookies
    @snoop[:session_options]   = request.session_options
    @snoop[:session]           = request.session.inspect
    @snoop[:load_path]         = $LOAD_PATH
    @snoop[:system_properties] = Hash[*Java::JavaLang::System.getProperties.to_a.flatten] if defined?(JRUBY_VERSION)
  end

  def hello
    forward_to "/hello?from+SnoopController"
  end

  def session_form
    session[:id]
    @session_hash = session.to_hash
  end

  def session_edit
    if request.post?
      session[params[:key]] = params[:value] if params[:key]
    end
    redirect_to :action => "session_form"
  end

  def error
    raise "you requested an error"
  end
end
