#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.logging.RackLoggerFactory

describe RackLoggerFactory, "getLogger" do
  after :each do
    java.lang.System.clearProperty("jruby.rack.logging")
  end

  def logger(context = @servlet_context)
    RackLoggerFactory.new(true).getLogger(context)
  end

  it "should construct a logger from the context init params over system properties" do
    context = mock "context"
    context.should_receive(:getInitParameter).with("jruby.rack.logging").and_return "clogging"
    java.lang.System.setProperty("jruby.rack.logging", "stdout")
    logger(context).should be_kind_of(org.jruby.rack.logging.CommonsLoggingLogger)
  end

  it "should construct a standard out logger when the logging attribute is unrecognized" do
    java.lang.System.setProperty("jruby.rack.logging", "other")
    logger.should be_kind_of(org.jruby.rack.logging.StandardOutLogger)
  end

  it "should constct a standard out logger when the logger can't be instantiated" do
    java.lang.System.setProperty("jruby.rack.logging", "java.lang.String")
    logger.should be_kind_of(org.jruby.rack.logging.StandardOutLogger)
  end

  it "should construct a servlet context logger by default" do
    logger.should be_kind_of(org.jruby.rack.logging.ServletContextLogger)
  end

  it "should allow specifying a class name in the logging attribute" do
    java.lang.System.setProperty("jruby.rack.logging", "org.jruby.rack.logging.CommonsLoggingLogger")
    logger.should be_kind_of(org.jruby.rack.logging.CommonsLoggingLogger)
  end
end
