#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

# Include or extend from this module to subscribe to a queue.
#
#     class MySubscriber
#       acts_as_subscriber
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
#       acts_as_subscriber
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
# #on_message. The former has priority and receive the raw JMS message
# object, while the second receives either the unmarshalled Ruby
# object or the text content of the message.
module JRuby::Rack::Queues
  module MessageSubscriber
    def subscribes_to(queue, &block)
      JRuby::Rack::Queues::Registry.register_listener(queue, self, &block)
    end
  end

  module ActsAsMessageSubscriber
    def acts_as_subscriber
      extend MessageSubscriber
    end
  end
end

if defined?(ActionController::Base)
  class ActionController::Base
    include JRuby::Rack::Queues::ActsAsMessageSubscriber
  end
end

if defined?(ActiveRecord::Base)
  class ActiveRecord::Base
    include JRuby::Rack::Queues::ActsAsMessageSubscriber
  end
end
