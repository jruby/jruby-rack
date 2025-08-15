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

  it "reads magic comment 1" do
    code = "# hello: world \n" +
           "# comment\n" +
           "exit(0);"
    string = IOHelpers.rubyMagicCommentValue(code, "hello:")
    expect(string).to eql "world"
  end

  it "reads magic comment 2" do
    code = "# encoding: UTF-8 \n" +
           "# comment\n" +
           "# rack.version: 1.3.6 \n" +
           "exit(0)\n'42'"
    string = IOHelpers.rubyMagicCommentValue(code, "rack.version:")
    expect(string).to eql "1.3.6"
  end

  it "works when reading an empty/null string" do
    expect(IOHelpers.rubyMagicCommentValue(nil, 'ruby.version:')).to be nil
    expect(IOHelpers.rubyMagicCommentValue('', 'ruby.version:')).to be nil
    expect(IOHelpers.rubyMagicCommentValue("\n", 'ruby.version:')).to be nil
  end

end