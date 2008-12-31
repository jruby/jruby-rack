#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues/local'

class JRuby::Rack::Queues
  # Configure ActiveMQ and set up queues and topics to be used. Example:
  #
  #   ActiveMQ.configure do |mq|
  #     mq.url = 'tcp://somehost:61616'
  #     mq.topics = %w(broadcast)
  #     mq.queues = %w(point2point)
  #   end
  class ActiveMQ
    def self.configure
      activemq = new
      yield activemq
    ensure
      activemq.register_jndi_properties
      ::JRuby::Rack::Queues.start_queue_manager
      at_exit do
        ::JRuby::Rack::Queues.queue_manager.destroy
      end
    end

    attr_writer :url, :topics, :queues

    def url
      @url ||= "vm://localhost"
    end

    def queues
      @queues ||= []
    end

    def topics
      @topics ||= []
    end

    def register_jndi_properties
      # Based on http://activemq.apache.org/jndi-support.html
      ::JRuby::Rack::Queues::LocalContext.init_parameters["jms.jndi.properties"] = <<-JNDI
java.naming.factory.initial = org.apache.activemq.jndi.ActiveMQInitialContextFactory

# use the following property to configure the default connector
java.naming.provider.url = #{url}

# use the following property to specify the JNDI name the connection factory
# should appear as.
#connectionFactoryNames = connectionFactory, queueConnectionFactory, topicConnectionFactory

# register some queues in JNDI using the form
# queue.[jndiName] = [physicalName]
#{generate_list('queue.', queues)}

# register some topics in JNDI using the form
# topic.[jndiName] = [physicalName]
#{generate_list('topic.', topics)}
JNDI
    end

    private
    def generate_list(prefix, names)
      list = ''
      names.each {|n| list << "#{prefix}#{n} = #{n}\n"}
      list
    end
  end
end
