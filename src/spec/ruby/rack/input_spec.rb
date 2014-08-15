#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

module InputSpec

  def self.included(base)
    base.extend SpecMethods
  end

  module SpecMethods

    def it_should_behave_like_rack_input

      it "should respond to gets and return a line" do
        input.gets.should == "hello\r\n"
        input.gets.should == "goodbye"
      end

      it "should return nil for gets at EOF" do
        2.times { input.gets }
        input.gets.should == nil
      end

      it "should respond to read" do
        input.read.should == "hello\r\ngoodbye"
      end

      it "should read a specified length" do
        input.read(5).should == "hello"
      end

      it "should read its full lenght" do
        input.read(16).should == "hello\r\ngoodbye"
      end

      it "should read into a provided buffer" do
        buf = ""
        input.read(nil, buf)
        buf.should == "hello\r\ngoodbye"
      end

      it "should read a specified amount into a provided buffer" do
        buf = ""
        input.read(5, buf)
        buf.should == "hello"
      end

      it "should replace contents of buffer" do
        buf = "cruft"
        input.read(5, buf)
        buf.should == "hello"
      end

      it "should respond to each and yield lines" do
        lines = []
        input.each {|l| lines << l}
        lines.should == ["hello\r\n", "goodbye"]
      end

    end

    def it_should_behave_like_rewindable_rack_input

      it_should_behave_like_rack_input

      it "should respond to rewind" do
        input.read
        input.read.should == ""
        input.rewind
        input.read.should == "hello\r\ngoodbye"
      end

    end

  end

  def stream_input(content = @content || "hello\r\ngoodbye")
    bytes = content.respond_to?(:to_java_bytes) ? content.to_java_bytes : content
    java.io.ByteArrayInputStream.new bytes
  end

  java_import 'org.jruby.rack.servlet.RewindableInputStream'

  def rewindable_input(buffer_size = nil, max_buffer_size = nil)
    buffer_size ||= RewindableInputStream::INI_BUFFER_SIZE
    max_buffer_size ||= RewindableInputStream::MAX_BUFFER_SIZE
    RewindableInputStream.new(stream_input, buffer_size, max_buffer_size)
  end

end

describe JRuby::Rack::Input do

  describe "rewindable" do
    include InputSpec

    let(:input) { JRuby::Rack::Input.new(rewindable_input) }

    it_should_behave_like_rewindable_rack_input

    let(:image_path) { File.expand_path('../files/image.jpg', File.dirname(__FILE__)) }

    it "reads an image" do
      file = java.io.RandomAccessFile.new(image_path, "r") # length == 4278
      file.read @content = Java::byte[file.length].new

      input = self.input

      buf = ""
      input.read(nil, buf)
      buf.size.should == file.length

      file.seek(0)
      buf.each_byte { |b| b.should == file.read }

      input.rewind

      file.seek(0)
      buf = input.read(1000)
      buf.size.should == 1000
      buf.each_byte { |b| b.should == file.read }

      buf = input.read(2000)
      buf.size.should == 2000
      buf.each_byte { |b| b.should == file.read }

      buf = input.read(2000)
      buf.size.should == 1278
      buf.each_byte { |b| b.should == file.read }

      10.times { input.read(2000).should be nil }

      input.rewind

      file.seek(0)
      buf = input.read
      buf.size.should == 4278
      buf.each_byte { |b| b.should == file.read }

      10.times { input.read.should == '' }
    end

    it "fully reads an image" do
      file = java.io.RandomAccessFile.new(image_path, "r") # length == 4278
      file.read @content = Java::byte[file.length].new
      file.seek(0)

      input = self.input

      buf = input.read(file.length)
      buf.size.should == 4278
      buf.each_byte { |b| b.should == file.read }
    end
  end

  describe "rewindable (with buffer size)" do
    include InputSpec

    let(:input) { JRuby::Rack::Input.new(rewindable_input(2)) }

    it_should_behave_like_rewindable_rack_input
  end

  describe "rewindable (with buffer size and max)" do
    include InputSpec

    before :each do
      @content = "1\n 2\n  3\n   4\n    5\r\t\n     6\n      7\n       8\n        9\n"
    end

    let(:input) { JRuby::Rack::Input.new(rewindable_input(4, 16)) }

    it "should be kind and rewind" do
      input.read.should == @content
      input.read.should == ""
      input.rewind
      input.read.should == @content
    end

    it "should be kind and rewind before read" do
      input.rewind
      input.read.should == @content
    end

    it "should be kind and rewind when gets some" do
      input.gets.should == "1\n"
      input.gets.should == " 2\n"
      input.rewind
      input.gets.should == "1\n"
      input.gets.should == " 2\n"
      input.gets.should == "  3\n"
      input.gets.should == "   4\n"
      input.read.should == "    5\r\t\n     6\n      7\n       8\n        9\n"
    end

  end

  describe "non-rewindable" do
    include InputSpec

    let(:input) { JRuby::Rack::Input.new(stream_input) }

    it_should_behave_like_rack_input
  end

  it "is exposed as JRuby::RackInput (backwards compat)" do
    expect( JRuby::RackInput ).to be JRuby::Rack::Input
  end

end
