
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

  let(:level) { org.jruby.rack.RackLogger::Level }

  let(:logger) { JRuby::Rack::Logger.new real_logger }

  before { JRuby::Rack.context = rack_context }
  after { JRuby::Rack.context = nil }

  it 'works with a servlet context' do
    logger.debug?
    logger.debug 'hogy basza meg a zold tucsok!'
    expect( real_logger.logged_content ).to match /^DEBUG.*hogy .* a zold tucsok!$/
  end

  it 'delegates to passed logger instance' do
    logger.debug 'debugging'
    expect( real_logger.logged_content ).to match /^DEBUG.*debugging$/
    real_logger.reset
    logger.info 'infooo'
    expect( real_logger.logged_content ).to match /^INFO.*infooo$/
    real_logger.reset
    logger.warn 'warning'
    expect( real_logger.logged_content ).to match /^WARN.*warning$/
    real_logger.reset
    logger.error 'errored'
    expect( real_logger.logged_content ).to match /^ERROR.*errored$/
    real_logger.reset
    logger.fatal 'totaal!'
    expect( real_logger.logged_content ).to match /^FATAL.*totaal!$/
  end

  it 'uses JRuby::Rack.context when no initialize argument' do
    logger = JRuby::Rack::Logger.new
    logger.debug?
    logger.debug 'hogy basza meg a zold tucsok!'
    expect( logger.real_logger ).to be rack_context
  end

  it 'delegates level check (when level is not set)' do
    real_logger.level = level::INFO
    expect( logger.debug? ).to be false
    expect( logger.info? ).to be true
    real_logger.level = level::WARN
    expect( logger.info? ).to be false
  end

  it 'uses level check when level is explicitly set' do
    real_logger.level = level::INFO
    logger.level = 2 # Logger.::WARN
    expect( logger.info? ).to be false
    expect( logger.warn? ).to be true
    logger.level = nil
    expect( logger.info? ).to be true
  end

  it "combines level check with delegate's level" do
    real_logger.level = level::WARN
    logger.level = 1 # Logger.::INFO
    expect( logger.debug? ).to be false
    expect( logger.info? ).to be false
    expect( logger.warn? ).to be true
    logger.level = nil
    expect( logger.info? ).to be false
    expect( logger.debug? ).to be false
    expect( logger.warn? ).to be true
  end

  it "disables real logger's formatting when formatter is set" do
    real_logger.formatting = true
    expect( real_logger.formatting? ).to be true

    logger.formatter = Proc.new { |severity, timestamp, progname, msg| "#{severity[0, 1]} #{msg}" }
    logger.warn 'hogy basza meg a zold tucsok!'
    expect( real_logger.logged_content ).to eql "W hogy basza meg a zold tucsok!\n"

    expect( real_logger.formatting? ).to be false
  end

#  it 'handles constant resolution (for Rails compatibility)' do
#    expect( logger.class::DEBUG ).to eql 0
#    expect( logger.class::FATAL ).to eql 4
#  end

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