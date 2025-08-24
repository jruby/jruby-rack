require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.DefaultRackConfig do

  let(:config) do
    config = org.jruby.rack.DefaultRackConfig.new
    config.quiet = true; config
  end

  let(:logger) { config.getLogger }

  it "constructs a standard out logger when the logging attribute is unrecognized" do
    java.lang.System.setProperty("jruby.rack.logging", "other")
    expect(logger).to be_a(org.jruby.rack.logging.StandardOutLogger)
  end

  it "constructs a standard out logger when the logger can't be instantiated" do
    java.lang.System.setProperty("jruby.rack.logging", "java.lang.String")
    expect(logger).to be_a(org.jruby.rack.logging.StandardOutLogger)
  end

  after { java.lang.System.clearProperty("jruby.rack.logging") }

end

describe org.jruby.rack.servlet.ServletRackConfig do

  let(:config) do
    config = org.jruby.rack.servlet.ServletRackConfig.new(@servlet_context)
    config.quiet = true; config
  end

  context "getLogger" do

    let(:logger) { config.getLogger }

    after { java.lang.System.clearProperty("jruby.rack.logging") }

    it "constructs a slf4j logger from the context init param" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.rack.logging").and_return "slf4j"
      expect(logger).to be_a(org.jruby.rack.logging.Slf4jLogger)
    end

    it "constructs a log4j logger from the context init param" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.rack.logging").and_return "log4j"
      expect(logger).to be_a(org.jruby.rack.logging.Log4jLogger)
    end

    it "constructs a commons logging logger from system properties" do
      java.lang.System.setProperty("jruby.rack.logging", "commons_logging")
      expect(logger).to be_a(org.jruby.rack.logging.CommonsLoggingLogger)
    end

    it "constructs a jul logger with logger name" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.rack.logging.name").and_return "/myapp"
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.rack.logging").and_return "JUL"
      expect(logger).to be_a(org.jruby.rack.logging.JulLogger)
      expect(logger.getLogger.name).to eq '/myapp'
    end

    it "constructs a slf4j logger with default logger name" do
      java.lang.System.setProperty("jruby.rack.logging", "slf4j")
      expect(logger).to be_a(org.jruby.rack.logging.Slf4jLogger)
      expect(logger.getLogger.name).to eq 'jruby.rack'
    end

    it "constructs a log4j logger with default logger name" do
      java.lang.System.setProperty("jruby.rack.logging", "log4j")
      expect(logger).to be_a(org.jruby.rack.logging.Log4jLogger)
      expect(logger.getLogger.name).to eq 'jruby.rack'
    end

    it "constructs a logger from the context init params over system properties" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.rack.logging").and_return "clogging"
      java.lang.System.setProperty("jruby.rack.logging", "stdout")
      expect(logger).to be_a(org.jruby.rack.logging.CommonsLoggingLogger)
    end

    it "constructs a servlet logger when the logging attribute is unrecognized" do
      java.lang.System.setProperty("jruby.rack.logging", "other")
      expect(logger).to be_a(org.jruby.rack.logging.ServletContextLogger)
    end

    it "constructs a servlet logger when the logger can't be instantiated" do
      java.lang.System.setProperty("jruby.rack.logging", "java.lang.String")
      expect(logger).to be_a(org.jruby.rack.logging.ServletContextLogger)
    end

    it "constructs a servlet context logger by default" do
      expect(logger).to be_a(org.jruby.rack.logging.ServletContextLogger)
    end

    it "allows specifying a class name in the logging attribute" do
      java.lang.System.setProperty("jruby.rack.logging", "org.jruby.rack.logging.CommonsLoggingLogger")
      expect(logger).to be_a(org.jruby.rack.logging.CommonsLoggingLogger)
    end
  end

  describe "runtime counts" do
    it "should retrieve the minimum and maximum counts from jruby.min and jruby.max.runtimes" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.min.runtimes").and_return "1"
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.max.runtimes").and_return "2"
      expect(config.initial_runtimes).to eq 1
      expect(config.maximum_runtimes).to eq 2
    end

    it "should recognize the jruby.pool.minIdle and jruby.pool.maxActive parameters from Goldspike" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.pool.minIdle").and_return "1"
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.pool.maxActive").and_return "2"
      expect(config.initial_runtimes).to eq 1
      expect(config.maximum_runtimes).to eq 2
    end
  end

  describe "runtime arguments" do
    it "should retrieve single argument from jruby.runtime.arguments" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return nil
      expect(config.runtime_arguments).to be_nil
    end

    it "should retrieve single argument from jruby.runtime.arguments" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return "--profile"
      args = config.runtime_arguments
      expect(args).not_to be_nil
      expect(args.length).to eq 1
      expect(args[0]).to eq "--profile"
    end

    it "should retrieve multiple argument from jruby.runtime.arguments" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.runtime.arguments").
        and_return " --compat RUBY1_8 \n --profile.api  --debug  \n\r"
      args = config.runtime_arguments
      expect(args).not_to be_nil
      expect(args.length).to eq 4
      expect(args[0]).to eq "--compat"
      expect(args[1]).to eq "RUBY1_8"
      expect(args[2]).to eq "--profile.api"
      expect(args[3]).to eq "--debug"
    end
  end

  describe "runtime environment" do

    it "defaults to nil (runtime should keep default from System env)" do
      expect(@servlet_context).to receive(:getInitParameter).
        with("jruby.runtime.env").and_return nil
      expect(config.getRuntimeEnvironment).to be nil
    end

    it "is empty when set to false" do
      expect(@servlet_context).to receive(:getInitParameter).
        with("jruby.runtime.env").and_return 'false'
      expect_empty_env config.getRuntimeEnvironment
    end

    it "custom env hash" do
      expect(@servlet_context).to receive(:getInitParameter).
        with("jruby.runtime.env").
        and_return "PATH=~/bin,HOME=/home/kares\nNAMES=Jozko, Ferko,Janko,GEM_HOME=/opt/rvm/gems\n"
      expect(config.getRuntimeEnvironment).to eql({
                                                    "PATH" => "~/bin", "HOME" => "/home/kares", "NAMES" => "Jozko, Ferko,Janko", "GEM_HOME" => "/opt/rvm/gems"
                                                  })
    end

    private

    def expect_empty_env(env)
      expect(env).to_not be nil
      expect(env).to be_empty
      # but mutable :
      env.put 'PATH', '~/bin'
    end

  end

  describe "rewindable" do

    it "defaults to true" do
      expect(config).to be_rewindable
    end

    it "can be configured" do
      expect(@servlet_context).to receive(:getInitParameter).
        with("jruby.rack.input.rewindable").and_return "false"
      expect(config).to_not be_rewindable
    end

  end

  describe "custom-properties" do

    it "parser an int property" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.timeout").and_return "1"
      expect(config.getNumberProperty('jruby.some.timeout')).to eql 1
    end

    it "returns a default value" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.timeout").and_return nil
      expect(config.getNumberProperty('jruby.some.timeout', java.lang.Integer.new(10))).to eql 10
    end

    it "parser a float property" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.timeout").and_return "0.25"
      expect(config.getNumberProperty('jruby.some.timeout')).to eql 0.25
    end

    it "parser a big negative value" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.timeout").and_return "-20000000000"
      expect(config.getNumberProperty('jruby.some.timeout')).to eql -20000000000.0
    end

    it "parser a boolean flag" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.flag").and_return "true"
      expect(config.getBooleanProperty('jruby.some.flag')).to be true
    end

    it "parser a boolean (falsy) flag" do
      expect(@servlet_context).to receive(:getInitParameter).with("jruby.some.flag").and_return "F"
      expect(config.getBooleanProperty('jruby.some.flag')).to be false
    end

  end

end
