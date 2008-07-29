require 'jruby/rack/queues'

class QueueController < ApplicationController
  skip_before_filter :verify_authenticity_token
  cattr_accessor :queue_count, :instance_writer => false
  @@queue_count = 0

  JRuby::Rack::Queues.register_listener("rack") do |msg|
    puts "Received message: #{msg.inspect}"
    self.queue_count += 1
  end

  def index
    if request.post?
      JRuby::Rack::Queues.send_message("rack", "hi")
    end
    render :text => "Queue count: #{queue_count}"
  end
end
