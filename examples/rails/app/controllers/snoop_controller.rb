require 'rails/info'

class SnoopController < ApplicationController
  def index
    @info = Rails::Info.to_html
    @request = {}
    @request[:env]               = request.env
    @request[:remote_addr]       = request.remote_addr
    @request[:remote_ip]         = request.remote_ip
    @request[:host_with_port]    = request.host_with_port
    @request[:path]              = request.path
    @request[:server_software]   = request.server_software
    @request[:cookies]           = request.cookies
    @request[:session_options]   = request.session_options
    @request[:session]           = request.session.inspect
    @load_path = { :load_path => $LOAD_PATH }
    @system_properties = Hash[*Java::JavaLang::System.getProperties.to_a.flatten] if defined?(JRUBY_VERSION)
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
end
