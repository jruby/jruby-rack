#--
# Copyright 2007-2009 Sun Microsystems, Inc.
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

      class LocalRackApplication
        include Java::OrgJrubyRack::RackApplication
        def getRuntime
          @runtime ||= begin
                         require 'jruby'
                         JRuby.runtime
                       end
        end
      end

      class LocalRackApplicationFactory
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

      class LocalContext
        include Java::OrgJrubyRack::RackContext

        def self.init_parameters
          @params ||= {'jms.connection.factory' => 'ConnectionFactory'}
        end

        def self.init_parameters=(params)
          @params = params
        end

        def getInitParameter(k)
          self.class.init_parameters[k]
        end

        def log(*args)
          puts *args
        end

        def getRackFactory
          @rack_factory ||= LocalRackApplicationFactory.new
        end
      end
    end
  end
end
