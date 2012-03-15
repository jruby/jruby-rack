
require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby'

describe org.jruby.rack.embed.Dispatcher do
  
  let(:application) { mock "application" }
  let(:context) { org.jruby.rack.embed.Context.new "test" }
  
  it "initializes $servlet_context" do
    $servlet_context = nil
    begin
      org.jruby.rack.embed.Dispatcher.new context, application
      $servlet_context.should be context
    ensure
      $servlet_context = nil
    end
  end

  it "initializes config from runtime" do
    out = java.io.ByteArrayOutputStream.new
    err = java.io.ByteArrayOutputStream.new
    config = org.jruby.RubyInstanceConfig.new
    config.output = java.io.PrintStream.new(out)
    config.error  = java.io.PrintStream.new(err)
    runtime = org.jruby.Ruby.newInstance(config)
    application.stub!(:getRuntime).and_return runtime

    $stdout = StringIO.new 'out'
    $stderr = StringIO.new 'err'

    org.jruby.rack.embed.Dispatcher.new context, application
    runtime.evalScriptlet "$stdout.puts 'out from out there!'"
    runtime.evalScriptlet "STDERR.puts 'error it is not ...'"

    out.toString.should == "out from out there!\n"
    err.toString.should == "error it is not ...\n"
  end
  
end
