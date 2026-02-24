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
      expect(subject["foo"]).to eq("bar")

      subject.setAttribute('bar', 42)
      expect(subject[:bar]).to eq(42)
    end

    it "sets attributes with []=" do
      subject["muu"] = hash = { :huu => 'HU!' }
      expect(subject.getAttribute('muu')).to be(hash)

      subject[:num] = 12
      expect(subject.getAttribute('num')).to eq(12)
    end

    it "deletes attributes" do
      subject.setAttribute('foo', 'bar')
      subject.setAttribute('xxx', 12345)

      subject.delete('foo')
      expect(subject.getAttribute('muu')).to be_nil

      expect { subject.delete('yyy') }.not_to raise_error

      expect(subject.getAttributeNames.to_a).to include('xxx')
      subject.delete(:xxx)
      expect(subject.getAttributeNames.to_a).not_to include('xxx')
    end

    it "reports (string) keys" do
      expect(subject.keys).to eq([])
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)

      expect(subject.keys).to eq(['foo', 'bar'])
    end

    it "reports values" do
      expect(subject.values).to eq([])
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)

      expect(subject.values).to eq(['muu', 12345])
    end

    it "yields attribute pairs on each" do
      subject.setAttribute('foo', 'muu')
      subject.setAttribute('bar', 12345)

      count = 0
      subject.each do |key, val|
        case count += 1
        when 1 then
          expect(key).to eq('foo')
          expect(val).to eq('muu')
        when 2 then
          expect(key).to eq('bar')
          expect(val).to eq(12345)
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
      expect(@request).to receive(:getAttribute).with("HA!").and_return "NYAH!"
      expect(@request["HA!"]).to eq("NYAH!")
    end

    it "should stringify the key, allowing symbols to be used as keys" do
      expect(@request).to receive(:getAttribute).with("foo").and_return "bar"
      expect(@request[:foo]).to eq("bar")
    end

    it "should allow #[]= to set request attributes" do
      expect(@request).to receive(:setAttribute).with("HA!", "NYAH!")
      @request["HA!"] = "NYAH!"
    end

    it "should give an array of keys from getAttributeNames" do
      names = %w(a b c)
      expect(@request).to receive(:getAttributeNames).and_return names
      expect(@request.keys).to eq(names)
    end

    let(:subject) { org.springframework.mock.web.MockHttpServletRequest.new }

    it_behaves_like "hash"

  end

  describe Java::JakartaServletHttp::HttpSession do

    before :each do
      @session = Java::JakartaServletHttp::HttpSession.impl {}
    end

    it "should allow #[] to access session attributes" do
      expect(@session).to receive(:getAttribute).with("HA!").and_return "NYAH!"
      expect(@session["HA!"]).to eq("NYAH!")
    end

    it "should stringify the key, allowing symbols to be used as keys" do
      expect(@session).to receive(:getAttribute).with("foo").and_return "bar"
      expect(@session[:foo]).to eq("bar")
    end

    it "should allow #[]= to set session attributes" do
      expect(@session).to receive(:setAttribute).with("HA!", "NYAH!")
      @session["HA!"] = "NYAH!"
    end

    it "should give an array of keys from getAttributeNames" do
      names = %w(a b c)
      expect(@session).to receive(:getAttributeNames).and_return names
      expect(@session.keys).to eq(names)
    end

    let(:subject) { org.springframework.mock.web.MockHttpSession.new }

    it_behaves_like "hash"

  end

end
