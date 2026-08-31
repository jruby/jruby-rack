# encoding: UTF-8
#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.util.IOHelpers do

  IOHelpers = org.jruby.rack.util.IOHelpers

  it "reads a stream into a string" do
    code = "# comment\n" +
           "puts 'vůl or kôň';\n" +
           "exit(0)\n"
    stream = java.io.ByteArrayInputStream.new code.to_java.getBytes('UTF-8')
    stream = java.io.BufferedInputStream.new(stream, 8)
    string = IOHelpers.inputStreamToString(stream)
    expect(string).to eql "# comment\nputs 'vůl or kôň';\nexit(0)\n"
  end

end