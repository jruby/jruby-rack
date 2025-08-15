require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.RackServletContextListener do

  RackServletContextListener = org.jruby.rack.RackServletContextListener

  before(:each) do
    allow(@servlet_context).to receive(:getInitParameter).and_return nil
    @factory = double "application factory"
    # @listener = RackServletContextListener.new(@factory) :
    application_factory = org.jruby.rack.RackApplicationFactory
    constructor = RackServletContextListener.java_class.to_java.
      getDeclaredConstructor(application_factory.java_class)
    constructor.accessible = true
    @listener = constructor.newInstance(@factory.to_java(application_factory))
  end

  let(:servlet_context_event) do
    javax.servlet.ServletContextEvent.new @servlet_context
  end

  describe "contextInitialized" do

    it "creates a Rack application factory and store it in the context" do
      expect(@servlet_context).to receive(:setAttribute).with(RackApplicationFactory::FACTORY, @factory)
      expect(@servlet_context).to receive(:setAttribute).with(RackApplicationFactory::RACK_CONTEXT, anything())
      allow(@factory).to receive(:init)
      @listener.contextInitialized servlet_context_event
    end

    it "initializes the application factory" do
      expect(@factory).to receive(:init)
      @listener.contextInitialized servlet_context_event
    end

    it "throws an error if initialization failed" do
      @servlet_context = org.springframework.mock.web.MockServletContext.new
      expect(@factory).to receive(:init).and_raise org.jruby.rack.RackInitializationException.new("help")

      expect { @listener.contextInitialized(servlet_context_event) }.to raise_error(org.jruby.rack.RackInitializationException)
    end

    it "does not throw if initialization failed (and jruby.rack.error = true)" do
      @servlet_context = org.springframework.mock.web.MockServletContext.new
      @servlet_context.addInitParameter 'jruby.rack.error', 'true'
      expect(@factory).to receive(:init).and_raise org.jruby.rack.RackInitializationException.new("help")

      expect { @listener.contextInitialized(servlet_context_event) }.to_not raise_error
    end

  end

  describe "contextDestroyed" do

    it "removes the application factory from the servlet context" do
      expect(@servlet_context).to receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return @factory
      expect(@servlet_context).to receive(:removeAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY)
      expect(@servlet_context).to receive(:removeAttribute).with(
        org.jruby.rack.RackApplicationFactory::RACK_CONTEXT)
      allow(@factory).to receive(:destroy)
      @listener.contextDestroyed servlet_context_event
    end

    it "destroys the application factory" do
      expect(@servlet_context).to receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return @factory
      allow(@servlet_context).to receive(:removeAttribute)
      expect(@factory).to receive(:destroy)
      @listener.contextDestroyed servlet_context_event
    end

    it "does nothing if no application is found in the context" do
      expect(@servlet_context).to receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return nil
      @listener.contextDestroyed servlet_context_event
    end

  end

  it "has a default constructor (for servlet container)" do
    expect { RackServletContextListener.new }.not_to raise_error
  end

  it "pools runtimes when max > 1" do
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return(2)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end

  it "does not pool when max = 1" do
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return(1)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

  it "does not pool by default" do
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

end

describe org.jruby.rack.rails.RailsServletContextListener do

  RailsServletContextListener = org.jruby.rack.rails.RailsServletContextListener

  it "has a default constructor (for servlet container)" do
    expect { RailsServletContextListener.new }.not_to raise_error
  end

  it "shares a runtime by default" do
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

  it "pools runtimes when max > 1" do
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return(2)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end

  it "pools runtimes when max > 1 and serial initialization" do
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return(3)
    allow(@rack_config).to receive(:isSerialInitialization).and_return(true)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.SerialPoolingRackApplicationFactory)
  end

  it "does not pool when max = 1" do
    allow(@rack_config).to receive(:getMaximumRuntimes).and_return(1)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    expect(factory).to be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

end
