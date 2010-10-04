#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'spec_helper'
require 'cgi/session/java_servlet_store'
require 'openssl'

describe CGI::Session::JavaServletStore do
  before :each do
    @session = mock "servlet session"
    @request = mock "servlet request"
    @options = {"java_servlet_request" => @request}
  end

  def session_store
    store = CGI::Session::JavaServletStore.new(nil, @options)
    store.data[:key] = :value
    store
  end

  it "should raise an error if the servlet request is not present" do
    @options.delete("java_servlet_request")
    lambda { session_store }.should raise_error
  end

  describe "#restore" do
    it "should do nothing if no session established" do
      @request.should_receive(:getSession).and_return nil
      session_store.restore.should == {}
    end

    it "should do nothing if the session does not have anything in it" do
      @request.should_receive(:getSession).with(false).and_return @session
      @session.should_receive(:getAttributeNames).and_return []
      session_store.restore.should == {}
    end

    it "should retrieve the marshalled session from the java session" do
      hash = {"foo" => 1, "bar" => true}
      marshal_data = Marshal.dump hash
      @request.should_receive(:getSession).with(false).and_return @session
      @session.should_receive(:getAttributeNames).and_return(
        [CGI::Session::JavaServletStore::RAILS_SESSION_KEY])
      @session.should_receive(:getAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY).and_return marshal_data.to_java_bytes
      session_store.restore.should == hash
    end

    it "should retrieve values from other keys in the session" do
      hash = {"foo" => 1, "bar" => true}
      @request.should_receive(:getSession).with(false).and_return @session
      @session.should_receive(:getAttributeNames).and_return ["foo", "bar"]
      @session.should_receive(:getAttribute).with("foo").and_return hash["foo"]
      @session.should_receive(:getAttribute).with("bar").and_return hash["bar"]
      session_store.restore.should == hash
    end

    it "should retrieve java objects in the session" do
      @request.should_receive(:getSession).with(false).and_return @session
      @session.should_receive(:getAttributeNames).and_return ["foo"]
      @session.should_receive(:getAttribute).with("foo").and_return java.lang.Object.new
      session_store.restore["foo"].should be_instance_of(java.lang.Object)
    end
  end

  describe "#update" do
    before :each do
      @request.should_receive(:getSession).with(true).and_return @session
    end

    it "should do nothing if the session data is empty" do
      store = session_store
      store.data.clear
      store.update
    end

    it "should marshal the session to the java session" do
      @session.should_receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY,
        an_instance_of(Java::byte[]))
      session_store.update
    end

    it "should store entries with string keys and values as java session attributes" do
      @session.should_receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY, anything)
      @session.should_receive(:setAttribute).with("foo", "bar")
      store = session_store
      store.data["foo"] = "bar"
      store.update
    end

    it "should store numeric, nil, or boolean values as java session attributes" do
      @session.should_receive(:setAttribute).with("foo", true)
      @session.should_receive(:setAttribute).with("bar", 20)
      @session.should_receive(:setAttribute).with("baz", nil)
      @session.should_receive(:setAttribute).with("quux", false)
      store = session_store
      store.data.clear
      store.data["foo"] = true
      store.data["bar"] = 20
      store.data["baz"] = nil
      store.data["quux"] = false
      store.update
    end

    it "should store java object values as java session attributes" do
      @session.should_receive(:setAttribute).with("foo", an_instance_of(java.lang.Object))
      store = session_store
      store.data.clear
      store.data["foo"] = java.lang.Object.new
      store.update
    end

    it "should not store entries with non-primitive values in the java session" do
      @session.should_receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY, anything)
      store = session_store
      store.data["foo"] = Object.new
      store.update
    end

  end

  describe "#close" do
    it "should do the same as update" do
      @request.should_receive(:getSession).with(true).and_return @session
      @session.should_receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY,
        an_instance_of(Java::byte[]))
      session_store.close
    end
  end

  describe "#delete" do
    it "should invalidate the servlet session" do
      @request.should_receive(:getSession).with(false).and_return @session
      @session.should_receive(:invalidate)
      session_store.delete
    end

    it "should do nothing if no session is established" do
      @request.should_receive(:getSession).with(false).and_return nil
      session_store.delete
    end
  end

  describe "#generate_digest" do
    before :each do
      @request.should_receive(:getSession).with(true).and_return @session
      @dbman = session_store
    end

    def hmac(key, data)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new("SHA1"), key, data)
    end

    it "should look for the secret in the java session" do
      @session.should_receive(:getAttribute).with("__rails_secret").and_return "secret"
      @dbman.generate_digest("key").should == hmac("secret", "key")
    end

    it "should generate a secret from the java session id and last accessed time" do
      @session.should_receive(:getAttribute).with("__rails_secret").and_return nil
      @session.should_receive(:getId).and_return "abc"
      @session.should_receive(:getLastAccessedTime).and_return 123
      @session.should_receive(:setAttribute).with("__rails_secret", "abc123")
      @dbman.generate_digest("key").should == hmac("abc123", "key")
    end
  end
end
