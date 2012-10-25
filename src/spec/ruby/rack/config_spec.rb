#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.servlet.ServletRackConfig do
  
  let(:config) do 
    config = org.jruby.rack.servlet.ServletRackConfig.new(@servlet_context)
    config.quiet = true; config
  end

  context "getLogger" do
    
    let(:logger) { config.getLogger }

    after :each do
      java.lang.System.clearProperty("jruby.rack.logging")
    end

    it "constructs a slf4j logger from the context init param" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.logging").and_return "slf4j"
      logger.should be_a(org.jruby.rack.logging.Slf4jLogger)
    end

    it "constructs a commons logging logger from system properties" do
      java.lang.System.setProperty("jruby.rack.logging", "commons_logging")
      logger.should be_a(org.jruby.rack.logging.CommonsLoggingLogger)
    end

    org.jruby.rack.logging.JulLogger.class_eval { field_reader :logger }
    
    it "constructs a jul logger with logger name" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.logging.name").and_return "/myapp"
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.logging").and_return "JUL"
      logger.should be_a(org.jruby.rack.logging.JulLogger)
      logger.logger.name.should == '/myapp'
    end

    org.jruby.rack.logging.Log4jLogger.class_eval { field_reader :logger }
    
    it "constructs a slf4j logger with default logger name" do
      java.lang.System.setProperty("jruby.rack.logging", "Log4J")
      logger.should be_a(org.jruby.rack.logging.Log4jLogger)
      logger.logger.name.should == 'jruby.rack'
    end
    
    it "constructs a logger from the context init params over system properties" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.logging").and_return "clogging"
      java.lang.System.setProperty("jruby.rack.logging", "stdout")
      logger.should be_a(org.jruby.rack.logging.CommonsLoggingLogger)
    end

    it "constructs a standard out logger when the logging attribute is unrecognized" do
      java.lang.System.setProperty("jruby.rack.logging", "other")
      logger.should be_a(org.jruby.rack.logging.StandardOutLogger)
    end

    it "constructs a standard out logger when the logger can't be instantiated" do
      java.lang.System.setProperty("jruby.rack.logging", "java.lang.String")
      logger.should be_a(org.jruby.rack.logging.StandardOutLogger)
    end

    it "constructs a servlet context logger by default" do
      logger.should be_a(org.jruby.rack.logging.ServletContextLogger)
    end

    it "allows specifying a class name in the logging attribute" do
      java.lang.System.setProperty("jruby.rack.logging", "org.jruby.rack.logging.CommonsLoggingLogger")
      logger.should be_a(org.jruby.rack.logging.CommonsLoggingLogger)
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

  describe "runtime arguments" do
    it "should retrieve single argument from jruby.runtime.arguments" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return nil
      config.runtime_arguments.should be_nil
    end
    
    it "should retrieve single argument from jruby.runtime.arguments" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return "--profile"
      args = config.runtime_arguments
      args.should_not be_nil
      args.length.should == 1
      args[0].should == "--profile"
    end
    
    it "should retrieve multiple argument from jruby.runtime.arguments" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return " --compat RUBY1_8 \n --profile.api  --debug  \n\r"
      args = config.runtime_arguments
      args.should_not be_nil
      args.length.should == 4
      args[0].should == "--compat"
      args[1].should == "RUBY1_8"
      args[2].should == "--profile.api"
      args[3].should == "--debug"
    end
  end
  
  describe "rewindable" do
    it "defaults to true" do
      config.should be_rewindable
    end

    it "is false when overridden by jruby.rack.input.rewindable" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.rack.input.rewindable").
        and_return "false"
      config.should_not be_rewindable
    end
  end

  it "sets compat version from init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
      and_return "RUBY1_9"
    expect( config.getCompatVersion ).to be org.jruby.CompatVersion::RUBY1_9
  end

  it "sets compat version from init parameter (dot syntax)" do
    @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
      and_return "1.8"
    expect( config.getCompatVersion ).to be org.jruby.CompatVersion::RUBY1_8
  end

  it "leaves compat version nil if not specified" do
    @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
      and_return nil
    expect( config.getCompatVersion ).to be nil
  end

  it "leaves compat version nil if invalid value specified" do
    @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
      and_return "4.2"
    expect( config.getCompatVersion ).to be nil
  end
  
  if JRUBY_VERSION >= '1.7.0'
    it "sets compat version 2.0 from init parameter" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
        and_return "RUBY2_0"
      expect( config.getCompatVersion ).to be org.jruby.CompatVersion::RUBY2_0
    end

    it "sets compat version 2.0 from init parameter (dot syntax)" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.compat.version").
        and_return "2_0"
      expect( config.getCompatVersion ).to be org.jruby.CompatVersion::RUBY2_0
    end
  end
  
  describe "custom-properties" do

    it "parser an int property" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.timeout").and_return "1"
      expect( config.getNumberProperty('jruby.some.timeout') ).to eql 1
    end

    it "returns a default value" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.timeout").and_return nil
      expect( config.getNumberProperty('jruby.some.timeout', java.lang.Integer.new(10)) ).to eql 10
    end
    
    it "parser a float property" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.timeout").and_return "0.25"
      expect( config.getNumberProperty('jruby.some.timeout') ).to eql 0.25
    end

    it "parser a big negative value" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.timeout").and_return "-20000000000"
      expect( config.getNumberProperty('jruby.some.timeout') ).to eql -20000000000.0
    end

    it "parser a boolean flag" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.flag").and_return "true"
      expect( config.getBooleanProperty('jruby.some.flag') ).to be true
    end

    it "parser a boolean (falsy) flag" do
      @servlet_context.should_receive(:getInitParameter).with("jruby.some.flag").and_return "F"
      expect( config.getBooleanProperty('jruby.some.flag') ).to be false
    end
    
  end
  
end
