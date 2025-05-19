require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.embed.Config do

  it "resolves properties from java.lang.System env" do
    begin
      java.lang.System.set_property "foo", "bar"
      java.lang.System.set_property "truish", "true"
      java.lang.System.set_property "falsish", "false"

      subject.get_property('foo').should == 'bar'
      subject.get_property('foo', 'BAR').should == 'bar'

      subject.get_boolean_property('truish').should == true
      subject.get_boolean_property('falsish', true).should == false
    ensure
      java.lang.System.clear_property "foo"
      java.lang.System.clear_property "truish"
      java.lang.System.clear_property "falsish"
    end
  end

#  it "honors properties from provided config if available" do
#    foo_config = org.jruby.rack.RackConfig.impl {}
#    def foo_config.getProperty(name, default = nil)
#      name == 'foo' ? 'bar' : default
#    end
#
#    constructor = org.jruby.rack.embed.Config.java_class.to_java.
#      getDeclaredConstructor([ org.jruby.rack.RackConfig.java_class ].to_java :'java.lang.Class')
#    constructor.setAccessible(true)
#    config = constructor.newInstance(foo_config) # org.jruby.rack.embed.Config.new(foo_config)
#
#    begin
#      java.lang.System.set_property "foo", "BAR"
#      java.lang.System.set_property "bar", "FOO"
#
#      config.getProperty('some').should be nil
#
#      config.getProperty('foo').should == 'bar'
#      config.getProperty('bar').should == 'FOO'
#    ensure
#      java.lang.System.clear_property "foo"
#      java.lang.System.clear_property "bar"
#    end
#  end

  context "initialized" do

    before(:each) do
      @config = org.jruby.rack.embed.Config.new
      @config.doInitialize JRuby.runtime
    end

    it "resolves properties from ENV" do
      begin
        ENV['env_foo'] = 'env_bar'
        ENV['env_true'] = 'true'
        ENV['env_false'] = 'false'

        @config.get_property('env_foo').should == 'env_bar'
        @config.get_property('env_true').should == 'true'

        @config.get_boolean_property('env_true').should == true
        @config.get_boolean_property('env_false').should == false
      ensure
        ENV.delete('env_foo')
        ENV.delete('env_true')
        ENV.delete('env_false')
      end
    end

    it "configures request buffer size from ENV" do
      begin
        ENV["jruby.rack.request.size.initial.bytes"] = '1024'
        ENV["jruby.rack.request.size.maximum.bytes"] = '4096'

        @config.getInitialMemoryBufferSize.should == 1024
        @config.getMaximumMemoryBufferSize.should == 4096
      ensure
        ENV.delete("jruby.rack.request.size.initial.bytes")
        ENV.delete("jruby.rack.request.size.treshold.bytes")
      end
    end

    it "sets compat version from runtime" do
      require 'jruby'
      compat_version = JRuby.runtime.instance_config.compat_version
      expect( @config.compat_version ).to eql compat_version
    end

    it "sets out/err streams from runtime" do
      out = java.io.ByteArrayOutputStream.new
      err = java.io.ByteArrayOutputStream.new
      config = org.jruby.RubyInstanceConfig.new
      config.output = java.io.PrintStream.new(out)
      config.error  = java.io.PrintStream.new(err)
      @config.doInitialize org.jruby.Ruby.newInstance(config)

      @config.getOut.println "hello out!"
      @config.getErr.println "hello err!"

      expect(out.toString).to include "hello out!\n"
      expect(err.toString).to include "hello err!\n"
    end

  end

end
