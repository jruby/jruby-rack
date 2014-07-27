#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe 'JRuby::Rack::ErrorApp' do

  before(:all) { require 'jruby/rack/error_app' }

  before :each do
    @servlet_request = double "servlet request"
    @env = {'java.servlet_request' => @servlet_request}
  end

  subject { JRuby::Rack::ErrorApp.new }

  it "should determine the response status code based on the exception in the servlet attribute" do
    init_exception

    expect( subject.call(@env)[0] ).to eql 500
    @env["rack.showstatus.detail"].should == "something went wrong"
  end

  it "returns 503 if there is a nested InterruptedException" do
    init_exception java.lang.InterruptedException.new
    response = subject.call(@env)

    expect( response[0] ).to eql 503
    expect( response[1] ).to be_a Hash
    expect( response[2] ).to eql []
  end

  it "returns 503 if it's an acquite timeout exception" do
    @env[ 'HTTP_ACCEPT' ] = 'text/html'
    @env[ JRuby::Rack::ErrorApp::EXCEPTION ] = org.jruby.rack.AcquireTimeoutException.new('failed')

    response = subject.call(@env)
    expect( response[0] ).to eql 503
    expect( response[1] ).to be_a Hash
    expect( response[2] ).to eql []
  end

  it "serves 503 if .html exists" do
    @env[ 'HTTP_ACCEPT' ] = '*/*'
    @env[ JRuby::Rack::ErrorApp::EXCEPTION ] = org.jruby.rack.AcquireTimeoutException.new('failed')

    in_tmpdir_with_files('503.html' => '-503-', '500.html' => '-500-') do |dir|
      error_app = JRuby::Rack::ErrorApp.new(dir)

      response = error_app.call(@env)
      expect( response[0] ).to eql 503
      expect( response[1] ).to include 'Last-Modified'
      expect( response[1] ).to include 'Content-Length'
      expect( response[1]['Content-Type'] ).to eql 'text/html'
      expect( body = response[2] ).to be_a JRuby::Rack::ErrorApp::FileBody
      content = ''; body.each { |chunk| content << chunk }
      expect( content ).to eql '-503-'
    end
  end

  it "serves 500 if 503 .html does not exist" do
    @env[ 'HTTP_ACCEPT' ] = '*/*'
    @env[ JRuby::Rack::ErrorApp::EXCEPTION ] = org.jruby.rack.AcquireTimeoutException.new('failed')

    _500_html = '1234567890' * 42_000
    in_tmpdir_with_files('500.html' => _500_html) do |dir|
      error_app = JRuby::Rack::ErrorApp.new(dir)

      response = error_app.call(@env)
      expect( response[0] ).to eql 500 # 503
      expect( response[1] ).to include 'Content-Length'
      expect( response[1]['Content-Type'] ).to eql 'text/html'
      expect( body = response[2] ).to be_a JRuby::Rack::ErrorApp::FileBody
      content = ''; body.each { |chunk| content << chunk }
      expect( content ).to eql _500_html
    end
  end

  private

  def init_exception(cause = nil)
    exception = org.jruby.rack.RackInitializationException.new("something went wrong", cause)
    @env[ org.jruby.rack.RackEnvironment::EXCEPTION ] = exception
  end

  require 'fileutils'; require 'tmpdir'

  def in_tmpdir_with_files(files = {})
    FileUtils.mkdir_p path = File.expand_path(Time.now.to_f.to_s, Dir.tmpdir)
    files.each do |name, content|
      File.open(File.join(path, name), 'w') { |file| file << content }
    end
    yield path
  ensure
    FileUtils.rm_rf(path) if path && File.exists?(path)
  end

end

describe 'JRuby::Rack::Errors' do

  before(:all) { require 'jruby/rack/errors' }

  it "still works (backward compat)" do
    expect( JRuby::Rack::Errors ).to be JRuby::Rack::ErrorApp
  end

end
