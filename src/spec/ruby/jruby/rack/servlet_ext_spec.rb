#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

describe 'servlet-ext' do
  
  before(:all) { require 'jruby/rack/servlet_ext' }
  
  shared_examples_for "hash" do
    
    it "returns attributes from []" do
      subject.setAttribute('foo', 'bar')
      subject["foo"].should == "bar"
      
      subject.setAttribute('bar', 42)
      subject[:bar].should == 42
    end

    it "sets attributes with []=" do
      subject["muu"] = hash = { :huu => 'HU!' }
      subject.getAttribute('muu').should be hash
      
      subject[:num] = 12
      subject.getAttribute('num').should == 12
    end

    it "deletes attributes" do
      subject.setAttribute('foo', 'bar')
      subject.setAttribute('xxx', 12345)
      
      subject.delete('foo')
      subject.getAttribute('muu').should be nil

      lambda { subject.delete('yyy') }.should_not raise_error
      
      subject.getAttributeNames.to_a.should include('xxx')
      subject.delete(:xxx)
      subject.getAttributeNames.to_a.should_not include('xxx')
    end

    it "reports (string) keys" do
      subject.keys.should == []
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)
      
      subject.keys.should == [ 'foo', 'bar' ]
    end

    it "reports values" do
      subject.values.should == []
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)
      
      subject.values.should == [ 'muu', 12345 ]
    end

    it "yields attribute pairs on each" do
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)
      
      count = 0
      subject.each do |key, val|
        case count += 1
        when 1 then
          key.should == 'foo'
          val.should == 'muu'
        when 2 then
          key.should == 'bar'
          val.should == 12345
        else
          fail "unexpected #{count}. yield with (#{key.inspect}, #{val.inspect})"
        end
      end
    end
    
  end
  
  describe Java::JakartaServlet::ServletContext do

    let(:subject) do 
      context = org.springframework.mock.web.MockServletContext.new
      context.removeAttribute("jakarta.servlet.context.tempdir")
      context
    end

    it_behaves_like "hash"
    
  end
  
  describe Java::JakartaServlet::ServletRequest do
    
    before :each do
      @request = Java::JakartaServlet::ServletRequest.impl {}
    end

    it "should allow #[] to access request attributes" do
      @request.should_receive(:getAttribute).with("HA!").and_return "NYAH!"
      @request["HA!"].should == "NYAH!"
    end

    it "should stringify the key, allowing symbols to be used as keys" do
      @request.should_receive(:getAttribute).with("foo").and_return "bar"
      @request[:foo].should == "bar"
    end

    it "should allow #[]= to set request attributes" do
      @request.should_receive(:setAttribute).with("HA!", "NYAH!")
      @request["HA!"] = "NYAH!"
    end

    it "should give an array of keys from getAttributeNames" do
      names = %w(a b c)
      @request.should_receive(:getAttributeNames).and_return names
      @request.keys.should == names
    end

    let(:subject) { org.springframework.mock.web.MockHttpServletRequest.new }

    it_behaves_like "hash"
    
  end

  describe Java::JakartaServletHttp::HttpSession do
    
    before :each do
      @session = Java::JakartaServletHttp::HttpSession.impl {}
    end

    it "should allow #[] to access session attributes" do
      @session.should_receive(:getAttribute).with("HA!").and_return "NYAH!"
      @session["HA!"].should == "NYAH!"
    end

    it "should stringify the key, allowing symbols to be used as keys" do
      @session.should_receive(:getAttribute).with("foo").and_return "bar"
      @session[:foo].should == "bar"
    end

    it "should allow #[]= to set session attributes" do
      @session.should_receive(:setAttribute).with("HA!", "NYAH!")
      @session["HA!"] = "NYAH!"
    end

    it "should give an array of keys from getAttributeNames" do
      names = %w(a b c)
      @session.should_receive(:getAttributeNames).and_return names
      @session.keys.should == names
    end
    
    let(:subject) { org.springframework.mock.web.MockHttpSession.new }

    it_behaves_like "hash"
    
  end
  
end
