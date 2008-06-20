#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.jms.QueueContextListener
import org.jruby.rack.jms.QueueManager

describe QueueContextListener do
  before :each do
    @qmf = mock "queue manager factory"
    @qm = mock "queue manager"
    @listener_event = javax.servlet.ServletContextEvent.new @servlet_context
    @listener = QueueContextListener.new @qmf
  end
  
  it "should create a new QueueManager, initialize it and store it in the application context" do
    @qmf.should_receive(:newQueueManager).ordered.and_return @qm
    @qm.should_receive(:init).with(an_instance_of(javax.servlet.ServletContext)).ordered
    @servlet_context.should_receive(:setAttribute).with(QueueContextListener::QUEUE_KEY, an_instance_of(QueueManager)).ordered
    @listener.contextInitialized(@listener_event)
  end

  it "should capture exceptions during initialization and log them to the servlet context" do
    @qmf.should_receive(:newQueueManager).and_return @qm
    @qm.should_receive(:init).and_raise StandardError.new("something happened!")
    @listener.contextInitialized(@listener_event)
  end
  
  it "should remove the QueueManager and destroy it" do
    qm = QueueManager.impl {}
    @servlet_context.should_receive(:getAttribute).with(QueueContextListener::QUEUE_KEY).and_return qm
    @servlet_context.should_receive(:removeAttribute).with(QueueContextListener::QUEUE_KEY)
    qm.should_receive(:destroy)
    @listener.contextDestroyed(@listener_event)
  end
end