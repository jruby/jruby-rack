#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/queues'

describe JRuby::Rack::Queues do
  before :each do
    $servlet_context = @servlet_context
  end
  after :each do
    $servlet_context = nil
  end

  it "#with_jms_connection should yield a JMS connection" do
    qm = mock "queue manager"
    @servlet_context.should_receive(:getAttribute).with(org.jruby.rack.jms.QueueContextListener::MGR_KEY).and_return qm
    conn_factory = mock "connection factory"
    qm.should_receive(:getConnectionFactory).and_return conn_factory
    conn = mock "connection"
    conn_factory.should_receive(:createConnection).ordered.and_return conn
    conn.should_receive(:createMessage).ordered
    conn.should_receive(:close).ordered

    JRuby::Rack::Queues.with_jms_connection do |c|
      c.createMessage
    end
  end
end