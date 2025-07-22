#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe 'JRuby::Rack::ErrorApp' do

  before(:all) { require 'jruby/rack/error_app' }

  let(:error_app) { JRuby::Rack::ErrorApp.new } # subject { error_app }

  before :each do
    @servlet_request = double "servlet request"
    @env = {'java.servlet_request' => @servlet_request}
    # for Rack::Request to work (rendered from ShowStatus's TEMPLATE) :
    @env["rack.url_scheme"] = 'http'
  end

  it "should determine the response status code based on the exception in the servlet attribute" do
    init_exception

    expect( error_app.call(@env)[0] ).to eql 500
    @env["rack.showstatus.detail"].should == "something went wrong"
  end

  it "returns 503 if there is a nested InterruptedException" do
    init_exception java.lang.InterruptedException.new
    response = error_app.call(@env)

    expect( response[0] ).to eql 503
    expect( response[1] ).to be_a Hash
    expect( response[2] ).to eql []
  end

  it "returns 503 if it's an acquite timeout exception" do
    @env[ 'HTTP_ACCEPT' ] = 'text/html'
    @env[ JRuby::Rack::ErrorApp::EXCEPTION ] = org.jruby.rack.AcquireTimeoutException.new('failed')

    response = error_app.call(@env)
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

  it spec = "still serves when retrieving exception's message fails" do
    @env[ 'HTTP_ACCEPT' ] = '*/*'
    @env[ JRuby::Rack::ErrorApp::EXCEPTION ] = InitException.new spec

    response = error_app.call(@env)
    expect( response[0] ).to eql 500
    expect( response[1] ).to be_a Hash
    expect( response[2] ).to eql []
  end

  class InitException < org.jruby.rack.RackInitializationException
    def message; raise super.to_s end
  end

  context 'show-status' do

    let(:show_status) do
      JRuby::Rack::ErrorApp::ShowStatus.new error_app
    end

    it "does not alter 'rack.showstatus.detail' when set" do
      @env[ 'HTTP_ACCEPT' ] = '*/*'; init_exception
      @env[ 'rack.showstatus.detail' ] = false

      response = show_status.call(@env)
      expect( response[0] ).to eql 500
      expect( @env[ 'rack.showstatus.detail' ] ).to be false
    end

    it "renders template" do
      @env[ 'HTTP_ACCEPT' ] = '*/*'; init_exception

      response = show_status.call(@env)
      expect( response[0] ).to eql 500
      body = response[2][0]
      expect( body ).to include 'Internal Server Error'
      expect( body ).to match /<div id="info">\n\s{4}<p>something went wrong<\/p>\n\s{2}<\/div>/m
    end

    it "does not render detail info when 'rack.showstatus.detail' set to false" do
      @env[ 'HTTP_ACCEPT' ] = '*/*'; init_exception
      @env[ 'rack.showstatus.detail' ] = false

      response = show_status.call(@env)
      expect( response[0] ).to eql 500
      expect( response[2][0] ).to match /<div id="info">\s*?<\/div>/m
      expect( @env[ 'rack.showstatus.detail' ] ).to be false
    end

    it "with response < 400 and 'rack.showstatus.detail' set to false does not render exception" do
      @env[ 'HTTP_ACCEPT' ] = '*/*'; init_exception
      @env[ 'rack.showstatus.detail' ] = false

      def error_app.map_error_code(exc); 399 end

      response = show_status.call(@env)
      expect( response[0] ).to eql 399
      # 399, {"Content-Type"=>"text/plain", "X-Cascade"=>"pass"}, []
      expect( @env[ 'rack.showstatus.detail' ] ).to be false
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
    FileUtils.rm_rf(path) if path && File.exist?(path)
  end

end

describe 'JRuby::Rack::Errors' do

  before(:all) { require 'jruby/rack/errors' }

  it "still works (backward compat)" do
    expect( JRuby::Rack::Errors ).to be JRuby::Rack::ErrorApp
  end

end
