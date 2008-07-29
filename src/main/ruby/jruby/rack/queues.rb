#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    class Queues
      Session = javax.jms.Session
      TextMessage = javax.jms.TextMessage
      MARSHAL_PAYLOAD = "ruby_marshal_payload"

      # Called into by the JRuby-Rack java code when an asynchronous message
      # is received.
      def self.receive_message(queue_name, message)
        listener = self.listeners[queue_name]
        return unless listener
        listener.dispatch(message)
      end

      # Sends a message to the named queue. The message is assumed to be a Ruby
      # object that will be marshalled and delivered to a Ruby receiver.
      #
      # If a block is given, the JMS session object is yielded, and allows custom
      # message construction. The block should return a JMS Message object.
      def self.send_message(queue_name, message_data = nil, &block)
        with_jms_connection do |connection|
          queue = queue_manager.lookup(queue_name)
          session = connection.createSession(false, Session::AUTO_ACKNOWLEDGE)
          producer = session.createProducer(queue)
          if block
            message = yield session
          else
            message = session.createBytesMessage
            message.setBooleanProperty(MARSHAL_PAYLOAD, true)
            message.writeBytes(Marshal.dump(message_data).to_java_bytes)
          end
          producer.send(message)
        end
      end

      # Register a Ruby listener on the given queue.
      def self.register_listener(queue_name, listener = nil, &block)
        self.listeners[queue_name] = MessageDispatcher.new(block.nil? ? listener : block)
        queue_manager.listen(queue_name)
      end

      def self.listeners
        @listeners ||= {}
      end

      # Helper method that yields a JMS connection resource, closing it after
      # the block completes.
      def self.with_jms_connection
        conn = queue_manager.getConnectionFactory.createConnection
        begin
          yield conn
        ensure
          conn.close
        end
      end

      def self.queue_manager
        @queue_manager ||= $servlet_context.getAttribute(org.jruby.rack.jms.QueueContextListener::MGR_KEY)
      end

      class MessageDispatcher
        def initialize(listener)
          @listener = listener
        end

        def dispatch(message, listener = nil)
          listener ||= @listener
          if listener.respond_to?(:on_jms_message)
            listener.on_jms_message(message)
            return
          end

          message = convert_message(message)

          if listener.respond_to?(:call)
            listener.call(message)
          elsif listener.respond_to?(:on_message)
            listener.on_message(message)
          elsif Class === listener
            dispatch(message, listener.new)
          else
            puts "message dropped on the floor: #{message.inspect}"
          end
        end

        def convert_message(message)
          if message.getBooleanProperty(MARSHAL_PAYLOAD)
            payload = ""
            # what's the most efficient way of doing this?
            java_bytes = java.lang.reflect.Array.newInstance(java.lang.Byte::TYPE, 1024)
            while (bytes_read = message.readBytes(java_bytes)) != -1
              payload << String.from_java_bytes(java_bytes)[0..bytes_read]
            end
            message = Marshal.load(payload)
          elsif message.respond_to?(:getText)
            message = message.getText
          end
          message
        end
      end
    end
  end
end