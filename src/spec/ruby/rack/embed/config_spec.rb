require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.embed.Config do

  it "resolves properties from java.lang.System env" do
    begin
      java.lang.System.set_property "foo", "bar"
      java.lang.System.set_property "truish", "true"
      java.lang.System.set_property "falsish", "false"

      expect(subject.get_property('foo')).to eq 'bar'
      expect(subject.get_property('foo', 'BAR')).to eq 'bar'

      expect(subject.get_boolean_property('truish')).to eq true
      expect(subject.get_boolean_property('falsish', true)).to eq false
    ensure
      java.lang.System.clear_property "foo"
      java.lang.System.clear_property "truish"
      java.lang.System.clear_property "falsish"
    end
  end

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

        expect(@config.get_property('env_foo')).to eq 'env_bar'
        expect(@config.get_property('env_true')).to eq 'true'

        expect(@config.get_boolean_property('env_true')).to eq true
        expect(@config.get_boolean_property('env_false')).to eq false
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

        expect(@config.getInitialMemoryBufferSize).to eq 1024
        expect(@config.getMaximumMemoryBufferSize).to eq 4096
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
      config.error = java.io.PrintStream.new(err)
      @config.doInitialize org.jruby.Ruby.newInstance(config)

      @config.getOut.println "hello out!"
      @config.getErr.println "hello err!"

      expect(out.toString).to include "hello out!\n"
      expect(err.toString).to include "hello err!\n"
    end

  end

end
