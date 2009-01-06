#--
# Copyright 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/queues'

# Include this module in any class to add a #publish_message method for
# easy message dispatching. Default queue names can be configured
# either by defining a #default_destination method that returns the
# queue name, or by including a custom module returned by the #To
# method:
#
#     class MyShinyObject
#       act_as_publisher "ShinyQ"
#     end
#     obj = MyShinyObject.new
#     obj.publish_message "hi" # => sends to "ShinyQ"
#
# The default queue name can still be overridden on a per-call basis
# by prepending a queue name argument.
#
#     obj.publish_message "DullQ", "hi" # => sends to "DullQ"
#
module JRuby::Rack::Queues
  module MessagePublisher
    def self.To(queue)
      m = Module.new do
        include JRuby::Rack::Queues::MessagePublisher
        define_method :default_destination do
          m.default_destination
        end
      end
      class << m; attr_accessor :default_destination; end
      m.default_destination = queue
      m
    end

    def publish_message(*args, &block)
      args_length = args.length + (block ? 1 : 0)
      if args_length < 2 && respond_to?(:default_destination)
        args.unshift default_destination
      end
      JRuby::Rack::Queues::Registry.publish_message(*args[0..1], &block)
    end
  end
  
  module ActAsMessagePublisher
    def act_as_publisher(queue = nil)
      include queue ? MessagePublisher::To(queue) : MessagePublisher
    end
  end
end

if defined? ActionController
  class ActionController::Base
    include JRuby::Rack::Queues::ActAsMessagePublisher
  end
end

if defined? ActiveRecord
  class ActiveRecord::Base
    include JRuby::Rack::Queues::ActAsMessagePublisher
  end
end
