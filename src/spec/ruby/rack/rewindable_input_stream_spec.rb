#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++


require 'spec_helper'
import org.jruby.rack.servlet.RewindableInputStream

describe RewindableInputStream do

  it "should read data one by one" do
    input = []; 49.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 6, 24)
    
    49.times do |i|
      stream.read.should == i
    end
    3.times { stream.read.should == -1 }
  end

  it "should read data than rewind and read again (in memory)" do
    @stream = it_should_read_127_bytes(32, 256)
    
    @stream.rewind
    
    it_should_read_127_bytes
  end

  it "should read data than rewind and read again (temp file)" do
    @stream = it_should_read_127_bytes(16, 64)
    
    @stream.rewind
    
    it_should_read_127_bytes
  end
  
  def it_should_read_127_bytes(init_size = nil, max_size = nil)
    input = []; 127.times { |i| input << i }
    stream = @stream || rewindable_input_stream(input.to_java(:byte), init_size, max_size)
    
    data = new_byte_array(7)
    stream.read(data, 0, 7).should == 7 # read 7 bytes
    7.times do |i|
      data[i].should == i
    end

    data = new_byte_array(42)
    stream.read(data, 10, 20).should == 20 # read 20 bytes
    10.times { |i| data[i].should == 0 }
    20.times do |i|
      data[i + 10].should == i + 7
    end
    10.times { |i| data[i + 30].should == 0 }

    data = new_byte_array(200)
    stream.read(data, 0, 200).should == 100 # read 100 bytes
    100.times do |i|
      data[i].should == i + 20 + 7
    end
    100.times { |i| data[i + 100].should == 0 }
    
    stream
  end
  
  it "should read incomplete data rewind and read until end" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 10, 50)
    
    data = new_byte_array(110)
    stream.read(data, 0, 5).should == 5
    5.times do |i|
      data[i].should == i
    end
    
    stream.rewind
    stream.read(data, 5, 88).should == 88
    88.times do |i|
      data[i + 5].should == i
    end
    stream.read.should == 88
    stream.read.should == 89

    stream.rewind
    stream.read(data, 10, 33).should == 33
    33.times do |i|
      data[i + 10].should == i
    end

    stream.rewind
    stream.read(data, 0, 101).should == 100
    100.times do |i|
      data[i].should == i
    end
    
    stream.read.should == -1
  end
  
  it "should rewind unread data" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 10, 50)
    stream.rewind
    
    data = new_byte_array(120)
    stream.read(data, 10, 110).should == 100
    100.times do |i|
      data[i + 10].should == i
    end    
  end
  
  it "should mark and reset" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 5, 20)
    
    15.times { stream.read }
    stream.markSupported.should == true
    stream.mark(50)
    
    35.times { |i| stream.read.should == 15 + i }
    
    stream.reset
    
    50.times { |i| stream.read.should == 15 + i }
    35.times { |i| stream.read.should == 65 + i }
    
    stream.read.should == -1
  end
  
  private

    def rewindable_input_stream(input, buffer_size = nil, max_buffer_size = nil)
      input = to_input_stream(input) unless input.is_a?(java.io.InputStream)
      buffer_size ||= RewindableInputStream::INI_BUFFER_SIZE
      max_buffer_size ||= RewindableInputStream::MAX_BUFFER_SIZE
      RewindableInputStream.new(input, buffer_size, max_buffer_size)
    end
  
    def to_input_stream(content = @content)
      bytes = content.respond_to?(:to_java_bytes) ? content.to_java_bytes : content
      java.io.ByteArrayInputStream.new(bytes)
    end
    
    def new_byte_array(length)
      java.lang.reflect.Array.newInstance(java.lang.Byte::TYPE, length)
    end
    
end