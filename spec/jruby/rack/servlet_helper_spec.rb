#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under a CPL 1.0/GPL 2.0/LGPL 2.1 tri-license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../../spec_helper'
require 'jruby/rack/servlet_helper'

describe JRuby::Rack::Result do
  before :each do
    @status, @headers, @body = mock("status"), mock("headers"), mock("body")
    @servlet_response = mock "servlet response"
    @result = JRuby::Rack::Result.new([@status, @headers, @body])
  end

  it "should write the status to the servlet response" do
    @status.should_receive(:to_i).and_return(200)
    @servlet_response.should_receive(:setStatus).with(200)
    @result.writeStatus(@servlet_response)
  end

  it "should write the headers to the servlet response" do
    @headers.should_receive(:each).and_return do |block|
      block.call "Content-Type", "text/html"
      block.call "Content-Length", "20"
      block.call "Server",  "Apache/2.2.x"
    end
    @servlet_response.should_receive(:setContentType).with("text/html")
    @servlet_response.should_receive(:setContentLength).with(20)
    @servlet_response.should_receive(:setHeader).with("Server", "Apache/2.2.x")
    @result.writeHeaders(@servlet_response)
  end

  it "should write the body to the servlet response" do
    @body.should_receive(:each).and_return do |block|
      block.call "hello"
      block.call "there"
    end
    stream = mock "output stream"
    @servlet_response.stub!(:getOutputStream).and_return stream
    stream.should_receive(:write).exactly(2).times
    
    @result.writeBody(@servlet_response)
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

  it "should default public root to '/WEB-INF/public'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/public").and_return "."
    create_helper
    @helper.public_root.should == "."
  end

  it "should determine the gem path from the gem.path init parameter" do
    @servlet_context.should_receive(:getInitParameter).with("gem.path").and_return "/blah"
    @servlet_context.should_receive(:getRealPath).with("/blah").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should default gem path to '/WEB-INF/gems'" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/gems").and_return "."
    create_helper
    @helper.gem_path.should == "."
  end

  it "should set Gem.path to the value of gem_path" do
    @servlet_context.should_receive(:getRealPath).with("/WEB-INF/gems").and_return "/blah"
    create_helper
    Gem.path.should include('/blah')
  end

  it "should create a logger that writes messages to the servlet context" do
    create_helper
    @servlet_context.should_receive(:log).with(/hello/)
    @helper.logger.info "hello"
  end
end