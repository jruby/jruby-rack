class JspController < ApplicationController
  def index
    servlet_request['message'] = 'Hello from Rails!'
    forward_to '/jsp/index.jsp'
  end
end
