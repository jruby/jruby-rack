#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues/local'

# Configure ActiveMQ and set up queues and topics to be used. Example:
#
#   ActiveMQ.configure do |mq|
#     mq.url = 'tcp://somehost:61616'
#     mq.topics = %w(broadcast)
#     mq.queues = %w(point2point)
#   end
class JRuby::Rack::Queues::ActiveMQ
  def self.configure
    activemq = new
    yield activemq
  ensure
    activemq.register_jndi_properties
    ::JRuby::Rack::Queues::Registry.start_queue_manager
    at_exit do
      ::JRuby::Rack::Queues::Registry.stop_queue_manager
    end
  end

  attr_writer :url, :topics, :queues
  attr_accessor :username, :password

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

#{username && ("java.naming.security.principal = " + username) || ""}
#{password && ("java.naming.security.credentials = " + password) || ""}

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
