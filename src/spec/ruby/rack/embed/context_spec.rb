require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe org.jruby.rack.embed.Context do
  let(:stream) { java.io.ByteArrayOutputStream.new }
  let(:server_info) { "test server" }
  let(:config) do
    org.jruby.rack.embed.Config.new.tap do |c|
      c.out = c.err = java.io.PrintStream.new(stream)
    end
  end
  let(:context) { org.jruby.rack.embed.Context.new(server_info, config) }
  let(:captured) { String.from_java_bytes(stream.to_byte_array) }

  it "outputs log messages out to stdout" do
    context.log "does this string appear?"
    expect(captured["does this string appear?"]).not_to be nil
  end

  it "outputs log messages with level and new line to stdout" do
    info = org.jruby.rack.embed.Context::INFO
    context.log info, "this is logging at its best"
    expect(captured).to eq "INFO: this is logging at its best\n"
  end

  it "outputs error log messages to stderr" do
    my_error =
      begin
        raise java.lang.RuntimeException.new "shizzle sticks"
      rescue java.lang.RuntimeException;
        $!;
      end

    context.log("an error, gosh", my_error)

    expect(captured["an error, gosh"]).not_to be nil
    expect(captured["shizzle sticks"]).not_to be nil
    expect(captured["RuntimeException"]).not_to be nil
  end

  context "with specific info" do
    let(:server_info) { "awesome power server" }

    it "returns the server info given to it as a constructor argument" do
      expect(context.get_server_info).to eq "awesome power server"
    end
  end
end
