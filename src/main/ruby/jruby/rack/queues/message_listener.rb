#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

# Extend this class to implement a message listener.
#
#     class MyListener < JRuby::Rack::Queues::MessageListener
#       listen_to "MyQ"
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
class JRuby::Rack::Queues::MessageListener
  def self.listen_to(queue)
    @queue = queue
    JRuby::Rack::Queues::Registry.register_listener(queue, self)
  end

  def on_message(message)
    raise "#on_message not implemented"
  end
end
