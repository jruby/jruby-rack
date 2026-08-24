class BodyController < ApplicationController
  include ActionView::Helpers::NumberHelper
  def index
    if request.post?
      flash[:message] = "You posted #{number_to_human_size body_size}."
    end
  end

  private
  def body_size
    bytes = 0
    request.body.rewind # Need to rewind to re-read body with Rack 3 - and rewindable bodies are not mandatory...
    while str = request.body.read(1024)
      bytes += str.size
    end
    bytes
  end
end
