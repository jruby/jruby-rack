
require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby'

describe org.jruby.rack.embed.Dispatcher do
  
  let(:application) { mock "application" }
  let(:context) { org.jruby.rack.embed.Context.new "test" }
  
  before { $servlet_context = nil }; after { $servlet_context = nil }
  
  it "initializes $servlet_context", :deprecated => true do
    org.jruby.rack.embed.Dispatcher.new context, application
    $servlet_context.should be context
  end

  it "initializes JRuby::Rack.context" do
    prev_context = JRuby::Rack.context
    JRuby::Rack.context = nil
    begin
      org.jruby.rack.embed.Dispatcher.new context, application
      expect( JRuby::Rack.context ).to be context
    ensure
      JRuby::Rack.context = prev_context
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
