class Snoop < Application
  
  def index
    @snoop = {}
    @snoop[:env]               = request.env
    @snoop[:remote_ip]         = request.remote_ip
    @snoop[:host]              = request.host
    @snoop[:path]              = request.path
    @snoop[:server_software]   = request.server_software
    @snoop[:cookies]           = request.cookies
    @snoop[:session]           = request.session.inspect
    @snoop[:load_path]         = $LOAD_PATH
    render
  end
  
end
