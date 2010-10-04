#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
# Force the class to be loaded on the Ruby side
require 'jruby'
Java::org.jruby.rack.input.RackRewindableInput.getRackRewindableInputClass(JRuby.runtime)
Java::org.jruby.rack.input.RackNonRewindableInput.getRackNonRewindableInputClass(JRuby.runtime)

# Set some private methods public for testing purposes
class JRuby::RackBaseInput
  public :stream=, :content_length=
end
class JRuby::RackRewindableInput
  public :threshold=
end

def stream_input
  java.io.ByteArrayInputStream.new("hello\r\ngoodbye".to_java_bytes)
end

def it_should_behave_like_rack_input
  it "should respond to gets and return a line" do
    @input.gets.should == "hello\r\n"
    @input.gets.should == "goodbye"
  end

  it "should return nil for gets at EOF" do
    2.times { @input.gets }
    @input.gets.should == nil
  end

  it "should respond to read" do
    @input.read.should == "hello\r\ngoodbye"
  end

  it "should read a specified amount" do
    @input.read(5).should == "hello"
  end

  it "should read into a provided buffer" do
    buf = ""
    @input.read(nil, buf)
    buf.should == "hello\r\ngoodbye"
  end

  it "should read a specified amount into a provided buffer" do
    buf = ""
    @input.read(5, buf)
    buf.should == "hello"
  end

  it "should replace contents of buffer" do
    buf = "cruft"
    @input.read(5, buf)
    buf.should == "hello"
  end

  it "should respond to each and yield lines" do
    lines = []
    @input.each {|l| lines << l}
    lines.should == ["hello\r\n", "goodbye"]
  end

end

def it_should_behave_like_rewindable_rack_input
  it_should_behave_like_rack_input
    it "should respond to rewind" do
    @input.read
    @input.read.should == ""
    @input.rewind
    @input.read.should == "hello\r\ngoodbye"
  end
end

describe JRuby::RackRewindableInput, "for inputs below the memory threshold" do
  before :each do
    @input = JRuby::RackRewindableInput.new
    @input.stream = stream_input
  end

  it_should_behave_like_rewindable_rack_input
end

describe JRuby::RackRewindableInput, "for inputs above the memory threshold" do
  before :each do
    @input = JRuby::RackRewindableInput.new
    @input.stream = stream_input
    @input.threshold = 1
  end

  it_should_behave_like_rewindable_rack_input
end

describe JRuby::RackRewindableInput, "for accurate content lengths below threshold" do
  before :each do
    @input = JRuby::RackRewindableInput.new
    @input.stream = stream_input
    @input.content_length = 13
  end

  it_should_behave_like_rewindable_rack_input
end

describe JRuby::RackRewindableInput, "for accurate content lengths above threshold" do
  before :each do
    @input = JRuby::RackRewindableInput.new
    @input.stream = stream_input
    @input.content_length = 13
    @input.threshold = 1
  end

  it_should_behave_like_rewindable_rack_input
end

describe JRuby::RackNonRewindableInput, "for unspecified content length" do
  before :each do
    @input = JRuby::RackNonRewindableInput.new
    @input.stream = stream_input
  end

  it_should_behave_like_rack_input
end
