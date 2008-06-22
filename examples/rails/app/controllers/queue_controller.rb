require 'jruby/rack/queues'

class QueueController < ApplicationController
  @@queue_count = 0
  JRuby::Rack::Queues.register_listener("rack") do
    @@queue_count += 1
  end

  def index
    if request.post?
      JRuby::Rack::Queues.send_message("rack", "hi")
    end
    render :text => "Queue count: #{@@queue_count}"
  end
end
