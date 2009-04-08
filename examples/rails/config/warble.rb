# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  # Temporary directory where the application is staged
  # config.staging_dir = "tmp/war"

  # Application directories to be included in the webapp.
  config.dirs = %w(app config lib log vendor tmp)

  # Additional files/directories to include, above those in config.dirs
  # config.includes = FileList["db"]

  # Additional files/directories to exclude
  # config.excludes = FileList["lib/tasks/*"]

  # Additional Java .jar files to include.  Note that if .jar files are placed
  # in lib (and not otherwise excluded) then they need not be mentioned here.
  # JRuby and JRuby-Rack are pre-loaded in this list.  Be sure to include your
  # own versions if you directly set the value
  # config.java_libs += FileList["lib/java/*.jar"]
  if ENV['JRUBY_RACK_SRC']
    config.java_libs.delete_if {|f| f =~ /jruby-rack/}
    config.java_libs += FileList["../../target/jruby-rack*.jar"]
  end

  # Loose Java classes and miscellaneous files to be placed in WEB-INF/classes.
  # config.java_classes = FileList["target/classes/**.*"]

  # One or more pathmaps defining how the java classes should be copied into
  # WEB-INF/classes. The example pathmap below accompanies the java_classes
  # configuration above. See http://rake.rubyforge.org/classes/String.html#M000017
  # for details of how to specify a pathmap.
  # config.pathmaps.java_classes << "%{target/classes/,}"

  # Gems to be packaged in the webapp.  Note that Rails gems are added to this
  # list if vendor/rails is not present, so be sure to include rails if you
  # overwrite the value
  # config.gems = ["activerecord-jdbc-adapter", "jruby-openssl"]
  # config.gems << "tzinfo"

  # Include gem dependencies not mentioned specifically
  config.gem_dependencies = true

  # Files to be included in the root of the webapp.  Note that files in public
  # will have the leading 'public/' part of the path stripped during staging.
  # config.public_html = FileList["public/**/*", "doc/**/*"]

  # Pathmaps for controlling how public HTML files are copied into the .war
  # config.pathmaps.public_html = ["%{public/,}p"]

  # Name of the war file (without the .war) -- defaults to the basename
  # of RAILS_ROOT
  # config.war_name = "mywar"

  # Value of RAILS_ENV for the webapp
  config.webxml.rails.env = 'production'

  # No JMS
  # config.webxml.jms.provider = nil
  # In-container JMS
  # config.webxml.jms.provider = 'local'
  # ActiveMQ
  # config.webxml.jms.provider = 'activemq'
  config.webxml.jms.provider = ENV['JMS_PROVIDER']

  if config.webxml.jms.provider
    if config.webxml.jms.provider == 'activemq'
      config.webxml.jms.connection.factory = "ConnectionFactory"
      config.webxml.jms.jndi.properties = <<-JNDI
java.naming.factory.initial = org.apache.activemq.jndi.ActiveMQInitialContextFactory

# use the following property to configure the default connector
java.naming.provider.url = vm://localhost

# use the following property to specify the JNDI name the connection factory
# should appear as.
#connectionFactoryNames = connectionFactory, queueConnectionFactory, topicConnectionFactry

# register some queues in JNDI using the form
# queue.[jndiName] = [physicalName]
queue.rack = rack

# register some topics in JNDI using the form
# topic.[jndiName] = [physicalName]
JNDI
    else
      config.webxml.jms.connection.factory = "jms/queues"
    end
  end

  # Application booter to use, one of :rack, :rails, or :merb. (Default :rails)
  # config.webxml.booter = :rails

  # Control the pool of Rails runtimes. Leaving unspecified means
  # the pool will grow as needed to service requests. It is recommended
  # that you fix these values when running a production server!
  config.webxml.jruby.min.runtimes = 1
  config.webxml.jruby.max.runtimes = 1

  # JNDI data source name
  # config.webxml.jndi = 'jdbc/rails'
end
