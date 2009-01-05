#
# To run this script, put jruby-rack and activemq-all jar files on
# your classpath, and run like:
#
#   jruby bench.rb
#

require 'jruby/rack/queues/activemq'

class JRuby::Rack::Queues
  NUM_MSGS = ENV['N'] && ENV['N'].to_i || 10000
  Q = "MyQueue"

  ActiveMQ.configure do |mq|
    mq.queues << Q
  end

  @running = true
  @counter = Java::JavaUtilConcurrentAtomic::AtomicInteger.new

  Registry.register_listener Q do |msg|
    val = @counter.incrementAndGet
    if val == NUM_MSGS
      time = Time.now - @start
      puts
      puts "Took #{'%.02f' % time} seconds to process #{val} messages (#{'%.02f' % (val.to_f/time)} msgs/sec)."
      @running = false
    end
  end

  puts "Starting"
  @start = Time.now
  1.upto(NUM_MSGS) do
    print '.'
    Registry.send_message Q, "hello-#{'%.02f' % rand}"
  end

  while @running
    sleep 1
  end
end
