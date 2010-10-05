#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

module JRuby::Rack::Queues
  # Include or extend from this module to subscribe to a queue.
  #
  #     class MySubscriber
  #       extend JRuby::Rack::Queues::MessageSubscriber
  #
  #       subscribes_to "MyQ"
  #
  #       def on_message(message)
  #         # process message here
  #       end
  #     end
  #
  # An alternative is to pass a block to #subscribe_to for customized
  # message dispatching:
  #
  #     class MySubscriber
  #       extend JRuby::Rack::Queues::MessageSubscriber
  #
  #       subscribes_to "MyQ" do |message|
  #         self.new.dispatch msg
  #       end
  #
  #       def dispatch(message)
  #         # process message here
  #       end
  #     end
  #
  # To receive a message, implement one of #on_jms_message or
  # #on_message. The former has priority and receives the raw JMS message
  # object, while the second receives either the unmarshalled Ruby
  # object or the text content of the message.
  module MessageSubscriber
    def subscribes_to(queue, &block)
      JRuby::Rack::Queues::Registry.register_listener(queue, self, &block)
    end
  end

  # Include this module in any class to add a #publish_message method for
  # easy message dispatching. Default queue names can be configured
  # either by defining a #default_destination method that returns the
  # queue name, or by including a custom module returned by the #To
  # method:
  #
  #     class MyShinyObject
  #       include JRuby::Rack::Queues::MessagePublisher::To("ShinyQ")
  #     end
  #     obj = MyShinyObject.new
  #     obj.publish_message "hi" # => sends to "ShinyQ"
  #
  # The default queue name can still be overridden on a per-call basis
  # by prepending a queue name argument.
  #
  #     obj.publish_message "DullQ", "hi" # => sends to "DullQ"
  #
  module MessagePublisher
    def self.To(queue)
      m = Module.new do
        include JRuby::Rack::Queues::MessagePublisher
        define_method :default_destination do
          m.default_destination
        end
      end
      class << m; attr_accessor :default_destination; end
      m.default_destination = queue
      m
    end

    def publish_message(*args, &block)
      args_length = args.length + (block ? 1 : 0)
      if args_length < 2 && respond_to?(:default_destination)
        args.unshift default_destination
      end
      JRuby::Rack::Queues::Registry.publish_message(*args[0..1], &block)
    end
  end
end
