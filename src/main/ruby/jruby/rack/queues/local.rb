#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

module JRuby
  module Rack
    module Queues
      class QueueRegistry
        def start_queue_manager
          @queue_manager ||= begin
                               dqm = Java::OrgJrubyRackJms::DefaultQueueManager.new
                               dqm.init(LocalContext.new)
                               dqm
                             end
        end

        def stop_queue_manager
          @queue_manager.destroy
        end
      end

      class LocalRackApplication < java.lang.Object
        include Java::OrgJrubyRack::RackApplication
        def getRuntime
          @runtime ||= begin
                         require 'jruby'
                         JRuby.runtime
                       end
        end
      end

      class LocalRackApplicationFactory < java.lang.Object
        include Java::OrgJrubyRack::RackApplicationFactory
        def newApplication
          getApplication
        end

        def getApplication
          @app ||= LocalRackApplication.new
        end

        def finishedWithApplication(app)
        end
      end

      class LocalConfig < java.lang.Object
        include Java::OrgJrubyRack::RackConfig
        
        def getJmsJndiProperties
          LocalContext.init_parameters['jms.jndi.properties']
        end
        
        def getJmsConnectionFactory
          LocalContext.init_parameters['jms.connection.factory']
        end
      end
      
      class LocalContext < java.lang.Object
        include Java::OrgJrubyRack::RackContext

        def self.init_parameters
          @params ||= {'jms.connection.factory' => 'ConnectionFactory'}
        end

        def self.init_parameters=(params)
          @params = params
        end
        
        def getConfig
          @rack_config ||= LocalConfig.new
        end

        def getInitParameter(k)
          self.class.init_parameters[k]
        end

        def log(msg, exception = nil)
          puts msg
          while exception.respond_to?(:getCause) && exception.getCause
            exception = exception.getCause
          end
          exception.printStackTrace
        end

        def getRackFactory
          @rack_factory ||= LocalRackApplicationFactory.new
        end
      end
    end
  end
end
