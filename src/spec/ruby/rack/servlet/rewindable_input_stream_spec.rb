#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe org.jruby.rack.servlet.RewindableInputStream do

  it "should read data one by one" do
    input = []; 49.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 6, 24)

    49.times { |i| expect(stream.read).to eq i }
    3.times { expect(stream.read).to eq -1 }

    stream.rewind

    49.times { |i| expect(stream.read).to eq i }
    2.times { expect(stream.read).to eq -1 }
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
    expect(stream.read(data, 0, 7)).to eq 7 # read 7 bytes
    7.times { |i| expect(data[i]).to eq i }

    data = new_byte_array(42)
    expect(stream.read(data, 10, 20)).to eq 20 # read 20 bytes
    10.times { |i| expect(data[i]).to eq 0 }
    20.times { |i| expect(data[i + 10]).to eq i + 7 }

    10.times { |i| expect(data[i + 30]).to eq 0 }

    data = new_byte_array(200)
    expect(stream.read(data, 0, 200)).to eq 100 # read 100 bytes
    100.times { |i| expect(data[i]).to eq i + 20 + 7 }
    100.times { |i| expect(data[i + 100]).to eq 0 }

    stream
  end

  it "should read incomplete data rewind and read until end" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 10, 50)

    data = new_byte_array(110)
    expect(stream.read(data, 0, 5)).to eq 5
    5.times { |i| expect(data[i]).to eq i }

    stream.rewind
    expect(stream.read(data, 5, 88)).to eq 88
    88.times { |i| expect(data[i + 5]).to eq i }
    expect(stream.read).to eq 88
    expect(stream.read).to eq 89

    stream.rewind
    expect(stream.read(data, 10, 33)).to eq 33
    33.times { |i| expect(data[i + 10]).to eq i }

    stream.rewind
    expect(stream.read(data, 0, 101)).to eq 100
    100.times { |i| expect(data[i]).to eq i }

    expect(stream.read).to eq -1
  end

  it "should rewind unread data" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 10, 50)
    stream.rewind

    data = new_byte_array(120)
    expect(stream.read(data, 10, 110)).to eq 100
    100.times { |i| expect(data[i + 10]).to eq i }
  end

  it "should mark and reset" do
    input = []; 100.times { |i| input << i }
    stream = rewindable_input_stream(input.to_java(:byte), 5, 20)

    15.times { stream.read }
    expect(stream.markSupported).to eq true
    stream.mark(50)

    35.times { |i| expect(stream.read).to eq 15 + i }

    stream.reset

    50.times { |i| expect(stream.read).to eq 15 + i }
    35.times { |i| expect(stream.read).to eq 65 + i }

    expect(stream.read).to eq -1
  end

  it "should read an image" do
    image = File.expand_path('../../files/image.jpg', File.dirname(__FILE__))
    file = java.io.RandomAccessFile.new(image, "r")
    file.read bytes = new_byte_array(file.length)

    stream = rewindable_input_stream(bytes)

    index = 0
    while stream.read != -1
      index += 1
    end
    expect(index).to eq file.length

    stream.rewind

    file.seek(0); index = 0
    while (byte = stream.read) != -1
      expect(byte).to eq file.read
      index += 1
    end
    expect(index).to eq file.length
  end

  it "should delete the tmp file on close" do
    class RewindableInputStream
      field_reader :bufferFilePath
    end

    input = '1234567890 42'
    stream = rewindable_input_stream(input, 10, 12)
    13.times { stream.read }

    expect(stream.bufferFilePath).not_to be nil
    expect(File.exist?(stream.bufferFilePath)).to be true

    stream.close
    expect(File.exist?(stream.bufferFilePath)).to be false
  end

  after :all do
    tmpdir = java.lang.System.getProperty("java.io.tmpdir")
    prefix = RewindableInputStream::TMP_FILE_PREFIX
    FileUtils.rm_r Dir.glob(File.join(tmpdir, "#{prefix}*"))
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