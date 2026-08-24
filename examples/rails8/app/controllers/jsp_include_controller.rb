class JspIncludeController < ApplicationController
  def index
    @today = Time.now.strftime("%m/%d/%Y")
  end
end
