#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import org.jruby.rack.servlet.ServletRackConfig

describe ServletRackConfig do
  let(:config) { ServletRackConfig.new(@servlet_context).tap {|c| c.quiet = true } }

  describe "getLogger" do
    let(:logger) { config.getLogger }

    after :each do
      java.lang.System.clearProperty("jruby.rack.logging")
    end

    it "constructs a logger from the context init params over system properties" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.logging").and_return "clogging"
      java.lang.System.setProperty("jruby.rack.logging", "stdout")
      logger.should be_kind_of(org.jruby.rack.logging.CommonsLoggingLogger)
    end

    it "constructs a standard out logger when the logging attribute is unrecognized" do
      java.lang.System.setProperty("jruby.rack.logging", "other")
      logger.should be_kind_of(org.jruby.rack.logging.StandardOutLogger)
    end

    it "constructs a standard out logger when the logger can't be instantiated" do
      java.lang.System.setProperty("jruby.rack.logging", "java.lang.String")
      logger.should be_kind_of(org.jruby.rack.logging.StandardOutLogger)
    end

    it "constructs a servlet context logger by default" do
      logger.should be_kind_of(org.jruby.rack.logging.ServletContextLogger)
    end

    it "allows specifying a class name in the logging attribute" do
      java.lang.System.setProperty("jruby.rack.logging", "org.jruby.rack.logging.CommonsLoggingLogger")
      logger.should be_kind_of(org.jruby.rack.logging.CommonsLoggingLogger)
    end
  end

  describe "runtime counts" do
    it "should retrieve the minimum and maximum counts from jruby.min and jruby.max.runtimes" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.min.runtimes").and_return "1"
      @servlet_context.should_receive(:getInitParameter).with("jruby.max.runtimes").and_return "2"
      config.initial_runtimes.should == 1
      config.maximum_runtimes.should == 2
    end

    it "should recognize the jruby.pool.minIdle and jruby.pool.maxActive parameters from Goldspike" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.pool.minIdle").and_return "1"
      @servlet_context.should_receive(:getInitParameter).with("jruby.pool.maxActive").and_return "2"
      config.initial_runtimes.should == 1
      config.maximum_runtimes.should == 2
    end
  end

  describe "rewindable" do
    it "defaults to true" do
      config.should be_rewindable
    end

    it "is false when overridden by jruby.rack.input.rewindable" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.input.rewindable").and_return "false"
      config.should_not be_rewindable
    end
  end
end
