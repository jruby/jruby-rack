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
        expect(input.gets).to eq "hello\r\n"
        expect(input.gets).to eq "goodbye"
      end

      it "should return nil for gets at EOF" do
        2.times { input.gets }
        expect(input.gets).to eq nil
      end

      it "should respond to read" do
        expect(input.read).to eq "hello\r\ngoodbye"
      end

      it "should read a specified length" do
        expect(input.read(5)).to eq "hello"
      end

      it "should read its full lenght" do
        expect(input.read(16)).to eq "hello\r\ngoodbye"
      end

      it "should read into a provided buffer" do
        buf = ""
        input.read(nil, buf)
        expect(buf).to eq "hello\r\ngoodbye"
      end

      it "should read a specified amount into a provided buffer" do
        buf = ""
        input.read(5, buf)
        expect(buf).to eq "hello"
      end

      it "should replace contents of buffer" do
        buf = "cruft"
        input.read(5, buf)
        expect(buf).to eq "hello"
      end

      it "should respond to each and yield lines" do
        lines = []
        input.each { |l| lines << l }
        expect(lines).to eq ["hello\r\n", "goodbye"]
      end

    end

    def it_should_behave_like_rewindable_rack_input

      it_should_behave_like_rack_input

      it "should respond to rewind" do
        input.read
        expect(input.read).to eq ""
        input.rewind
        expect(input.read).to eq "hello\r\ngoodbye"
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
      expect(buf.size).to eq file.length

      file.seek(0)
      buf.each_byte { |b| expect(b).to eq file.read }

      input.rewind

      file.seek(0)
      buf = input.read(1000)
      expect(buf.size).to eq 1000
      buf.each_byte { |b| expect(b).to eq file.read }

      buf = input.read(2000)
      expect(buf.size).to eq 2000
      buf.each_byte { |b| expect(b).to eq file.read }

      buf = input.read(2000)
      expect(buf.size).to eq 1278
      buf.each_byte { |b| expect(b).to eq file.read }

      10.times { expect(input.read(2000)).to be nil }

      input.rewind

      file.seek(0)
      buf = input.read
      expect(buf.size).to eq 4278
      buf.each_byte { |b| expect(b).to eq file.read }

      10.times { expect(input.read).to eq '' }
    end

    it "fully reads an image" do
      file = java.io.RandomAccessFile.new(image_path, "r") # length == 4278
      file.read @content = Java::byte[file.length].new
      file.seek(0)

      input = self.input

      buf = input.read(file.length)
      expect(buf.size).to eq 4278
      buf.each_byte { |b| expect(b).to eq file.read }
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
      expect(input.read).to eq @content
      expect(input.read).to eq ""
      input.rewind
      expect(input.read).to eq @content
    end

    it "should be kind and rewind before read" do
      input.rewind
      expect(input.read).to eq @content
    end

    it "should be kind and rewind when gets some" do
      expect(input.gets).to eq "1\n"
      expect(input.gets).to eq " 2\n"
      input.rewind
      expect(input.gets).to eq "1\n"
      expect(input.gets).to eq " 2\n"
      expect(input.gets).to eq "  3\n"
      expect(input.gets).to eq "   4\n"
      expect(input.read).to eq "    5\r\t\n     6\n      7\n       8\n        9\n"
    end

  end

  describe "non-rewindable" do
    include InputSpec

    let(:input) { JRuby::Rack::Input.new(stream_input) }

    it_should_behave_like_rack_input
  end

  it "is exposed as JRuby::RackInput (backwards compat)" do
    expect(JRuby::RackInput).to be JRuby::Rack::Input
  end

end
