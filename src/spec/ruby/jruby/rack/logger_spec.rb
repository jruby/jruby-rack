
describe JRuby::Rack::Logger do

  let(:real_logger) do
    org.jruby.rack.logging.BufferLogger.new
  end

  let(:servlet_context) do
    servlet_context = org.jruby.rack.mock.MockServletContext.new
    servlet_context.logger = real_logger
    servlet_context
  end

  let(:rack_config) do
    org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
  end

  let(:rack_context) do
    org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
  end

  before { JRuby::Rack.context = rack_context }
  after { JRuby::Rack.context = nil }

  it 'works with a servlet context' do
    logger = JRuby::Rack::Logger.new real_logger
    logger.debug?
    logger.debug 'hogy basza meg a zold tucsok!'
    expect( real_logger.logged_content ).to match /^DEBUG.*hogy .* a zold tucsok!$/
  end

  describe JRuby::Rack::ServletLog do

    it "writes messages to the servlet context" do
      JRuby::Rack.context = rack_context = double('context')
      servlet_log = JRuby::Rack.send(:servlet_log)
      rack_context.should_receive(:log).with(/hello/)
      servlet_log.write "hello"
      rack_context.should_receive(:log).with(/hoja!/)
      servlet_log.puts "hoja!hoj"
      servlet_log.close
    end

  end

end