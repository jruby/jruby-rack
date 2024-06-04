require 'erb'

class JRuby::Rack::ErrorApp

  # catches empty responses and replaces them with a site explaining the error.
  #
  # @note kindly adapted from on Rack::ShowStatus
  # @private internal API - likely won't exist in 1.2
  class ShowStatus

    def initialize(app)
      require 'rack/request'; require 'rack/utils'
      @app = app; @template = ERB.new(TEMPLATE, nil, '-')
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)
      empty = headers['Content-Length'].to_i <= 0

      detail = env['rack.showstatus.detail']
      # client or server error, or explicit message
      if (status.to_i >= 400 && empty) || detail
        # required erb template variables (captured with binding) :
        request = req = ::Rack::Request.new(env); request && req # avoid un-used warning
        message = Utils::HTTP_STATUS_CODES[status.to_i] || status.to_s
        detail = detail.nil? ? message : detail # false for no detail

        body = @template.result(binding)
        size = Utils.bytesize(body)
        [status, headers.merge('Content-Type' => "text/html", 'Content-Length' => size.to_s), [body]]
      else
        [status, headers, body]
      end
    end

    # @private
    def h(obj)
      obj.is_a?(String) ? Utils.escape_html(obj) : Utils.escape_html(obj.inspect)
    end

    # :stopdoc:

# adapted from Django <djangoproject.com>
# Copyright (c) 2005, the Lawrence Journal-World
# Used under the modified BSD license:
# http://www.xfree86.org/3.3.6/COPYRIGHT2.html#5
TEMPLATE = <<'HTML'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <title><%=h message %> at <%=h request.script_name + request.path_info %></title>
  <meta name="robots" content="NONE,NOARCHIVE" />
  <style type="text/css">
    html * { padding:0; margin:0; }
    body * { padding:10px 20px; }
    body * * { padding:0; }
    body { font:small sans-serif; background:#eee; }
    body>div { border-bottom:1px solid #ddd; }
    h1 { font-weight:normal; margin-bottom:.4em; }
    h1 span { font-size:60%; color:#666; font-weight:normal; }
    table { border:none; border-collapse: collapse; width:100%; }
    td, th { vertical-align:top; padding:2px 3px; }
    th { width:12em; text-align:right; color:#666; padding-right:.5em; }
    #info { background:#f6f6f6; }
    #info ol { margin: 0.5em 4em; }
    #info ol li { font-family: monospace; }
    #summary { background: #ffc; }
    #explanation { background:#eee; border-bottom: 0px none; }
  </style>
</head>
<body>
  <div id="summary">
    <h1><%=h message %> <span>(<%= status.to_i %>)</span></h1>
    <table class="meta">
      <tr>
        <th>Request Method:</th>
        <td><%=h request.request_method %></td>
      </tr>
      <tr>
        <th>Request URL:</th>
        <td><%=h request.url %></td>
      </tr>
    </table>
  </div>
  <div id="info">
    <% if detail -%><p><%=h detail %></p><% end %>
  </div>

  <div id="explanation">
    <p>
    You're seeing this error because you use <code>JRuby::Rack::ErrorApp::ShowStatus</code>.
    </p>
  </div>
</body>
</html>
HTML

  end
end
