require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.RackServletContextListener do

  RackServletContextListener = org.jruby.rack.RackServletContextListener

  before(:each) do
    @servlet_context.stub(:getInitParameter).and_return nil
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
      @servlet_context.should_receive(:setAttribute).with(RackApplicationFactory::FACTORY, @factory)
      @servlet_context.should_receive(:setAttribute).with(RackApplicationFactory::RACK_CONTEXT, anything())
      @factory.stub(:init)
      @listener.contextInitialized servlet_context_event
    end

    it "initializes the application factory" do
      @factory.should_receive(:init)
      @listener.contextInitialized servlet_context_event
    end

    it "logs an error if initialization failed" do
      @factory.should_receive(:init).and_raise org.jruby.rack.RackInitializationException, "help"
      @servlet_context.should_receive(:log) do |level, message, error|
        level == 'ERROR' && message =~ /initialization failed/ && error.message == 'help'
      end
      @listener.contextInitialized servlet_context_event
    end

    it "throws an error if initialization failed (and jruby.rack.error = false)" do
      @servlet_context = org.jruby.rack.mock.MockServletContext.new
      @servlet_context.add_init_parameter 'jruby.rack.error', 'false'
      @factory.should_receive(:init).and_raise org.jruby.rack.RackInitializationException.new("help")

      expect { @listener.contextInitialized servlet_context_event }.to raise_error(org.jruby.rack.RackInitializationException)
    end

  end

  describe "contextDestroyed" do

    it "removes the application factory from the servlet context" do
      @servlet_context.should_receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return @factory
      @servlet_context.should_receive(:removeAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY)
      @servlet_context.should_receive(:removeAttribute).with(
        org.jruby.rack.RackApplicationFactory::RACK_CONTEXT)
      @factory.stub(:destroy)
      @listener.contextDestroyed servlet_context_event
    end

    it "destroys the application factory" do
      @servlet_context.should_receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return @factory
      @servlet_context.stub(:removeAttribute)
      @factory.should_receive(:destroy)
      @listener.contextDestroyed servlet_context_event
    end

    it "does nothing if no application is found in the context" do
      @servlet_context.should_receive(:getAttribute).with(
        org.jruby.rack.RackApplicationFactory::FACTORY).and_return nil
      @listener.contextDestroyed servlet_context_event
    end

  end

  it "has a default constructor (for servlet container)" do
    lambda { RackServletContextListener.new }.should_not raise_error
  end

  it "pools runtimes when max > 1" do
    @rack_config.stub(:getMaximumRuntimes).and_return(2)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end

  it "does not pool when max = 1" do
    @rack_config.stub(:getMaximumRuntimes).and_return(1)
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

  it "does not pool by default" do
    factory = RackServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

end

describe org.jruby.rack.rails.RailsServletContextListener do

  RailsServletContextListener = org.jruby.rack.rails.RailsServletContextListener

  it "has a default constructor (for servlet container)" do
    lambda { RailsServletContextListener.new }.should_not raise_error
  end

  it "pools runtimes by default" do
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.PoolingRackApplicationFactory)
  end

  it "pools runtimes when max > 1" do
    @rack_config.stub(:getMaximumRuntimes).and_return(3)
    @rack_config.stub(:isSerialInitialization).and_return(true)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SerialPoolingRackApplicationFactory)
  end

  it "does not pool when max = 1" do
    @rack_config.stub(:getMaximumRuntimes).and_return(1)
    factory = RailsServletContextListener.new.
      send(:newApplicationFactory, @rack_config)
    factory.should be_a(org.jruby.rack.SharedRackApplicationFactory)
  end

end
