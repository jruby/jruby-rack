#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/servlet_helper'

describe JRuby::Rack::Response do
  before :each do
    @status, @headers, @body = mock("status"), mock("headers"), mock("body")
    @headers.stub!(:[]).and_return nil
    @servlet_response = mock "servlet response"
    @response = JRuby::Rack::Response.new([@status, @headers, @body])
  end

  it "should return the status, headers and body" do
    @response.getStatus.should == @status
    @response.getHeaders.should == @headers
    @body.should_receive(:each).and_yield "hello"
    @response.getBody.should == "hello"
  end
  
  it "should write the status to the servlet response" do
    @status.should_receive(:to_i).and_return(200)
    @servlet_response.should_receive(:setStatus).with(200)
    @response.write_status(@servlet_response)
  end

  it "should write the headers to the servlet response" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Server",  "Apache/2.2.x"
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Server", "Apache/2.2.x")
    @response.write_headers(@servlet_response)
  end

  it "should write headers with multiple values multiple addHeader invocations" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Set-Cookie",  %w(cookie1 cookie2)
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie1")
    @servlet_response.should_receive(:addHeader).with("Set-Cookie", "cookie2")
    @response.write_headers(@servlet_response)
  end

  it "should write the body to the servlet response" do
    @body.should_receive(:each).and_return do |block|
      block.call "hello"
      block.call "there"
    end
    stream = mock "output stream"
    @servlet_response.stub!(:getOutputStream).and_return stream
    stream.should_receive(:write).exactly(2).times
    
    @response.write_body(@servlet_response)
  end

  it "should write the status first, followed by the headers, and the body last" do
    @response.should_receive(:write_status).ordered
    @response.should_receive(:write_headers).ordered
    @response.should_receive(:write_body).ordered
    @response.respond(@servlet_response)
  end

  it "should forward the request if the special 'Forward' header is present" do
    response = nil
    @headers.should_receive(:[]).with("Forward").and_return(proc {|resp| response = resp})
    @response.respond(@servlet_response)
    response.should == @servlet_response
  end
end

describe JRuby::Rack::ServletHelper do
  before :each do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @servlet_context.stub!(:getRealPath).and_return "/"
  end

  def create_helper
    @helper = JRuby::Rack::ServletHelper.new @servlet_context
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should convert public.root to not have any trailing slashes" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return "/blah/"
    @servlet_context.should_receive(:getRealPath).with("/blah/").and_return "/blah/"
    create_helper
    @helper.public_root.should == "/blah"
  end

  it "should also understand the 'files.prefix' init parameter from Goldspike" do
    @servlet_context.should_receive(:getInitParameter).with("public.root").and_return nil
    @servlet_context.should_receive(:getInitParameter).with("files.prefix").and_return ""
    @servlet_context.should_receive(:getRealPath).with("/").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should default public root to '/WEB-INF/public'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_helper
    @helper.public_root.should == "./public"
  end

  it "should determine the gem path from the gem.path init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "."
    create_helper
    @helper.gem_path.should == "./gems"
  end

  it "should set Gem.path to the value of gem_path" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    create_helper
    ENV['GEM_PATH'].should == "/blah/gems"
  end

  it "should create a logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end
end

describe JRuby::Rack::Errors do
  before :each do
    @servlet_request = mock "servlet request"
    @env = {'java.servlet_request' => @servlet_request}
    @file_server = mock "file server"
    @errors = JRuby::Rack::Errors.new @file_server
  end

  def init_exception(cause = nil)
    @exception = org.jruby.rack.RackInitializationException.new("something went wrong", cause)
    @env[org.jruby.rack.RackDispatcher::EXCEPTION] = @exception
  end

  it "should determine the response status code based on the exception in the servlet attribute" do
    init_exception
    @file_server.stub!(:call).and_return [404, {}, []]
    @errors.call(@env).should == [500, {}, []]
    @env["rack.showstatus.detail"].should == "something went wrong"
  end

  it "should return 503 if there is a nested InterruptedException" do
    init_exception java.lang.InterruptedException.new
    @file_server.stub!(:call).and_return [404, {}, []]
    @errors.call(@env).should == [503, {}, []]
  end

  it "should invoke the file server with PATH_INFO=/500.html" do
    init_exception
    @file_server.should_receive(:call).and_return do |env|
      env["PATH_INFO"].should == "/500.html"
      [200, {"Content-Type" => "text/html"}, ["custom error page"]]
    end
    @errors.call(@env).should == [500, {"Content-Type" => "text/html"}, ["custom error page"]]
    @env["rack.showstatus.detail"].should be_nil
  end

  it "should cache responses from the file server" do
    init_exception
    @file_server.should_receive(:call).once.and_return do |env|
      env["PATH_INFO"].should == "/500.html"
      [200, {"Content-Type" => "text/html"}, ["custom error page"]]
    end
    @errors.call(@env)
    @errors.call(@env)
    @errors.call(@env).should == [500, {"Content-Type" => "text/html"}, ["custom error page"]]
  end

  it "should expand and cache the body of the file" do
    init_exception
    object = Object.new
    def object.each
      yield "1"
      yield "2"
      yield "3"
    end
    @file_server.should_receive(:call).once.and_return do |env|
      env["PATH_INFO"].should == "/500.html"
      [200, {"Content-Type" => "text/html"}, object]
    end
    @errors.call(@env)
    @errors.call(@env)
    @errors.call(@env).should == [500, {"Content-Type" => "text/html"}, ["123"]]
  end
end