#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

import java.lang.System
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import org.jruby.rack.embed.Context
import org.jruby.rack.DefaultRackConfig

describe Context do
  let(:stream) { ByteArrayOutputStream.new }
  let(:server_info) { "test server" }
  let(:config) do
    DefaultRackConfig.new.tap do |c|
      c.out = c.err = PrintStream.new(stream)
    end
  end
  let(:context) { Context.new(server_info, config) }
  let(:captured) { String.from_java_bytes(stream.to_byte_array) }

  it "outputs log messages out to stdout" do
    context.log "does this string appear?"
    captured["does this string appear?"].should_not be_nil
  end

  it "outputs error log messages to stderr" do
    my_error = begin
      raise java.lang.RuntimeException.new "shizzle sticks"
    rescue java.lang.RuntimeException; $! ; end

    context.log("an error, gosh", my_error)

    captured["an error, gosh"].should_not be_nil
    captured["shizzle sticks"].should_not be_nil
    captured["RuntimeException"].should_not be_nil
  end

  context "with specific info" do
    let(:server_info) { "awesome power server" }

    it "returns the server info given to it as a constructor argument" do
      context.get_server_info.should == "awesome power server"
    end
  end
end
