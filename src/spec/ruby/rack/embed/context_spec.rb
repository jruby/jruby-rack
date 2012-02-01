#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'

import java.lang.System
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import org.jruby.rack.embed.Context
import org.jruby.rack.DefaultRackConfig

describe Context do

  def create_context(info="test server")
    Context.new(info)
  end

  def capture_stream(streamname, &block)
    capture_bytes = ByteArrayOutputStream.new
    print_stream = PrintStream.new capture_bytes
    original_out = System.send(streamname)
    set_method_sym = "set_#{streamname}".to_sym

    begin
      System.send(set_method_sym, print_stream)
      yield
    ensure
      System.send(set_method_sym, original_out)
    end
    print_stream.flush
    capture_bytes.to_string
  end

  it "outputs log messages out to stdout" do
    embed_context = create_context
    captured = capture_stream(:out) { embed_context.log "does this string appear?" }
    captured["does this string appear?"].should_not be_nil
  end

  it "outputs error log messages to stderr" do
    embed_context = create_context

    my_error = begin 
      raise java.lang.RuntimeException.new "shizzle sticks"
    rescue java.lang.RuntimeException; $! ; end

    captured = capture_stream(:err) { embed_context.log("an error, gosh", my_error)  }
    
    captured["an error, gosh"].should_not be_nil
    captured["shizzle sticks"].should_not be_nil
    captured["RuntimeException"].should_not be_nil
  end

  it "returns the server info given to it as a constructor argument" do
    server_info = create_context("awesome power server").get_server_info
    server_info.should eql("awesome power server")
  end

  it "returns a default config object via getConfig" do
    create_context.get_config.should be_an_instance_of DefaultRackConfig
  end

end
