unless defined?($servlet_context)
  require 'jruby/rack/queues/activemq'
  JRuby::Rack::Queues::ActiveMQ.configure do |mq|
    mq.queues << "rack"
  end
end
