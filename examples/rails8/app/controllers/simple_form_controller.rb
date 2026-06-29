class SimpleFormController < ApplicationController
  def index
    if request.post?
      require 'pp'
      flash[:message] = "You posted these params:"
      @params = params.pretty_inspect
    end
  end
end
