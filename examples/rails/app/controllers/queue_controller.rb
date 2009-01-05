require 'jruby/rack/queues'

class QueueController < ApplicationController
  skip_before_filter :verify_authenticity_token
  cattr_accessor :queue_count, :instance_writer => false
  @@queue_count = 0

  include JRuby::Rack::Queues::MessagePublisher::To("rack")
  extend JRuby::Rack::Queues::MessageSubscriber

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
