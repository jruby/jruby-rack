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
      MARSHAL_PAYLOAD = "ruby.marshal.payload"

      def self.receive_message(queue_name, message)
        listener = self.listeners[queue_name]
        return unless listener

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
          receive_message(queue_name, listener.new)
        end
      end

      def self.convert_message(message)
        if message.getBooleanProperty(MARSHAL_PAYLOAD)
          payload = ""
          java_bytes = ("\0" * 1024).to_java_bytes
          while (bytes_read = message.readBytes(java_bytes)) != -1
            payload << String.from_java_bytes(java_bytes)[0..bytes_read]
          end
          message = Marshal.load(java_bytes)
        elsif message.kind_of?(TextMessage)
          message = message.getText
        end
        message
      end

      def self.send_message(queue_name, message)
        with_jms_connection do |connection|
          queue = queue_manager.lookup(queue_name)
          session = connection.createSession(false, Session::AUTO_ACKNOWLEDGE)
          producer = session.createProducer(queue)
          message = session.createBytesMessage
          message.setBooleanProperty(MARSHAL_PAYLOAD, true)
          message.writeBytes(Marshal.dump(message).to_java_bytes)
          producer.send(message)
        end
      end

      def self.register_listener(queue_name, listener)
        self.listeners[queue_name] = listener
        queue_manager.listen(queue_name)
      end

      def self.listeners
	@listeners ||= {}
      end

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
    end
  end
end