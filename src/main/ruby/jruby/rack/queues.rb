#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module JRuby
  module Rack
    module Queues
      Session = Java::JavaxJms::Session
      MARSHAL_PAYLOAD = "ruby_marshal_payload"

      class QueueRegistry
        def initialize
          setup_rails_dispatcher_prepare_hook
        end

        # Called into by the JRuby-Rack java code when an asynchronous message
        # is received.
        def receive_message(queue_name, message)
          listener = listeners[queue_name]
          raise_dispatch_error(message) unless listener
          listener.dispatch(message)
        end

        # Sends a message to the named queue. The message is assumed to be a Ruby
        # object that will be marshalled and delivered to a Ruby receiver.
        #
        # If a block is given, the JMS session object is yielded, and allows custom
        # message construction. The block should return a JMS Message object.
        def publish_message(queue_name, message_data = nil, &block)
          with_jms_connection do |connection|
            queue = queue_manager.lookup(queue_name)
            session = connection.createSession(false, Session::AUTO_ACKNOWLEDGE)
            producer = session.createProducer(queue)
            if block
              message = yield session
            elsif String === message_data
              message = session.createTextMessage
              message.setText message_data
            else
              message = session.createBytesMessage
              message.setBooleanProperty(MARSHAL_PAYLOAD, true)
              message.writeBytes(Marshal.dump(message_data).to_java_bytes)
            end
            producer.send(message)
          end
        end

        # Register a Ruby listener on the given queue.
        def register_listener(queue_name, listener = nil, &block)
          array_dispatcher = (listeners[queue_name] ||= ArrayMessageDispatcher.new)
          array_dispatcher.add_dispatcher MessageDispatcher.new(block.nil? ? listener : block)
          queue_manager.listen(queue_name)
        end

        def unregister_listener(listener)
          listeners.delete_if do |k,v|
            v.delete_listener listener
            if v.empty?
              queue_manager.close(k)
              true
            end
          end
        end

        def listeners
          @listeners ||= {}
        end

        def clear_listeners
          listeners.clear
        end

        # Helper method that yields a JMS connection resource, closing it after
        # the block completes.
        def with_jms_connection
          conn = queue_manager.getConnectionFactory.createConnection
          begin
            yield conn
          ensure
            conn.close
          end
        end

        def queue_manager
          @queue_manager ||= $servlet_context.getAttribute(Java::OrgJrubyRackJms::QueueManager::MGR_KEY)
        end

        def raise_dispatch_error(message)
          $servlet_context.log "Unable to dispatch: #{message.inspect}" if $servlet_context
          raise "Unable to dispatch: #{message.inspect}"
        end

        def setup_rails_dispatcher_prepare_hook
          if defined?(::Rails)
            begin               # Rails 3
              require 'action_dispatch'
              ActionDispatch::Callbacks.to_prepare do
                ::JRuby::Rack::Queues::Registry.clear_listeners
              end
              return
            rescue Exception => e
            end
            begin               # Rails 2
              require 'dispatcher'
              dispatcher = defined?(ActionController::Dispatcher) &&
                ActionController::Dispatcher || defined?(::Dispatcher) && ::Dispatcher
              if dispatcher && dispatcher.respond_to?(:to_prepare)
                dispatcher.to_prepare do
                  ::JRuby::Rack::Queues::Registry.clear_listeners
                end
              end
            rescue Exception => e
            end
          end
        end
      end

      Registry = QueueRegistry.new

      class MessageDispatcher
        attr_reader :listener

        def initialize(listener)
          @listener = listener
        end

        def dispatch(message, listener = nil)
          listener ||= @listener
          begin
            if listener.respond_to?(:on_jms_message)
              listener.on_jms_message(message)
              return
            end

            message = convert_message(message)

            if listener.respond_to?(:call)
              listener.call(message)
              return
            elsif listener.respond_to?(:on_message)
              listener.on_message(message)
              return
            end
          rescue Exception => e
            $servlet_context.log("Error during message dispatch: " +
                                 e.to_s + "\nMessage: #{message.inspect}") if $servlet_context
            raise
          end

          if Class === listener
            dispatch(message, listener.new)
          else
            JRuby::Rack::Queues::Registry.raise_dispatch_error(message)
          end
        end

        def convert_message(message)
          if message.getBooleanProperty(MARSHAL_PAYLOAD)
            payload = ""
            java_bytes = Java::byte[1024].new
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

      class ArrayMessageDispatcher
        def initialize
          @dispatchers = []
        end

        def add_dispatcher(d)
          @dispatchers << d unless @dispatchers.detect {|dispatcher| dispatcher.listener == d.listener }
          self
        end

        def delete_listener(l)
          @dispatchers.delete_if {|dispatcher| dispatcher.listener == l }
        end

        def empty?
          @dispatchers.empty?
        end

        def dispatch(message)
          raised_exception = nil
          @dispatchers.each do |l|
            begin
              l.dispatch(message)
            rescue Exception => e
              raised_exception ||= e
            end
          end
          raise raised_exception if raised_exception
        end
      end
    end
  end
end

require 'jruby/rack/queues/pubsub'
