#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

# Include or extend from this module to subscribe to a queue.
#
#     class MySubscriber
#       act_as_subscriber
#
#       subscribes_to "MyQ"
#
#       def self.on_message(message)
#         # process message here
#       end
#     end
#
# An alternative is to pass a block to #subscribe_to for customized
# message dispatching:
#
#     class MySubscriber
#       act_as_subscriber
#
#       subscribes_to "MyQ" do |message|
#         self.new.on_message msg
#       end
#
#       def on_message(message)
#         # process message here
#       end
#     end
#
# To receive a message, implement one of #on_jms_message or
# #on_message. The former has priority and receive the raw JMS message
# object, while the second receives either the unmarshalled Ruby
# object or the text content of the message.
module JRuby::Rack::Queues
  module MessageSubscriber
    def subscribes_to(queue, &block)
      JRuby::Rack::Queues::Registry.register_listener(queue, self, &block)
    end
  end
  
  module ActAsMessageSubscriber
    def act_as_subscriber
      extend MessageSubscriber
    end
  end
end

if defined? ActiveRecord
  class ActiveRecord::Base
    extend JRuby::Rack::Queues::ActAsMessageSubscriber
  end
end
