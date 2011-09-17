class JspController < ApplicationController
  def index
    servlet_request['message'] = "This is being rendered by a JSP!"
    forward_to '/jsp/index.jsp'
    render :nothing => true
  end
end
