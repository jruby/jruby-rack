class JspForwardController < ApplicationController
  def index
    request.forward_to '/jsp/index.jsp', {:message => "This is being rendered by a JSP!"}
    render :nothing => true
  end
end
