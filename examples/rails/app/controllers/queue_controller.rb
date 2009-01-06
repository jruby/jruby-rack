require 'jruby/rack/queues'

class QueueController < ApplicationController
  
  act_as_publisher "rack"
  act_as_subscriber
  
  skip_before_filter :verify_authenticity_token
  cattr_accessor :queue_count, :instance_writer => false
  @@queue_count = 0

  subscribes_to "rack" do |msg|
    puts "Received message: #{msg.inspect}"
    self.queue_count += 1
  end

  def index
    if request.post?
      publish_message params[:msg] || "hi"
    end
    render :text => "Queue count: #{queue_count}\n"
  end
end
