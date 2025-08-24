#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'cgi/session/java_servlet_store'
require 'openssl'

describe CGI::Session::JavaServletStore do
  before :each do
    @session = double "servlet session"
    @request = double "servlet request"
    @options = { "java_servlet_request" => @request }
  end

  def session_store
    store = CGI::Session::JavaServletStore.new(nil, @options)
    store.data[:key] = :value
    store
  end

  it "should raise an error if the servlet request is not present" do
    @options.delete("java_servlet_request")
    expect { session_store }.to raise_error(RuntimeError)
  end

  describe "#restore" do
    it "should do nothing if no session established" do
      expect(@request).to receive(:getSession).and_return nil
      expect(session_store.restore).to eq({})
    end

    it "should do nothing if the session does not have anything in it" do
      expect(@request).to receive(:getSession).with(false).and_return @session
      expect(@session).to receive(:getAttributeNames).and_return []
      expect(session_store.restore).to eq({})
    end

    it "should retrieve the marshalled session from the java session" do
      hash = { "foo" => 1, "bar" => true }
      marshal_data = Marshal.dump hash
      expect(@request).to receive(:getSession).with(false).and_return @session
      expect(@session).to receive(:getAttributeNames).and_return(
        [CGI::Session::JavaServletStore::RAILS_SESSION_KEY])
      expect(@session).to receive(:getAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY).and_return marshal_data.to_java_bytes
      expect(session_store.restore).to eq hash
    end

    it "should retrieve values from other keys in the session" do
      hash = { "foo" => 1, "bar" => true }
      expect(@request).to receive(:getSession).with(false).and_return @session
      expect(@session).to receive(:getAttributeNames).and_return ["foo", "bar"]
      expect(@session).to receive(:getAttribute).with("foo").and_return hash["foo"]
      expect(@session).to receive(:getAttribute).with("bar").and_return hash["bar"]
      expect(session_store.restore).to eq hash
    end

    it "should retrieve java objects in the session" do
      expect(@request).to receive(:getSession).with(false).and_return @session
      expect(@session).to receive(:getAttributeNames).and_return ["foo"]
      expect(@session).to receive(:getAttribute).with("foo").and_return java.lang.Object.new
      expect(session_store.restore["foo"]).to be_instance_of(java.lang.Object)
    end
  end

  describe "#update" do
    before :each do
      expect(@request).to receive(:getSession).with(true).and_return @session
    end

    it "should do nothing if the session data is empty" do
      store = session_store
      store.data.clear
      store.update
    end

    it "should marshal the session to the java session" do
      expect(@session).to receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY,
        an_instance_of(Java::byte[]))
      session_store.update
    end

    it "should store entries with string keys and values as java session attributes" do
      expect(@session).to receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY, anything)
      expect(@session).to receive(:setAttribute).with("foo", "bar")
      store = session_store
      store.data["foo"] = "bar"
      store.update
    end

    it "should store numeric, nil, or boolean values as java session attributes" do
      expect(@session).to receive(:setAttribute).with("foo", true)
      expect(@session).to receive(:setAttribute).with("bar", 20)
      expect(@session).to receive(:setAttribute).with("baz", nil)
      expect(@session).to receive(:setAttribute).with("quux", false)
      store = session_store
      store.data.clear
      store.data["foo"] = true
      store.data["bar"] = 20
      store.data["baz"] = nil
      store.data["quux"] = false
      store.update
    end

    it "should store java object values as java session attributes" do
      expect(@session).to receive(:setAttribute).with("foo", an_instance_of(java.lang.Object))
      store = session_store
      store.data.clear
      store.data["foo"] = java.lang.Object.new
      store.update
    end

    it "should not store entries with non-primitive values in the java session" do
      expect(@session).to receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY, anything)
      store = session_store
      store.data["foo"] = Object.new
      store.update
    end

  end

  describe "#close" do
    it "should do the same as update" do
      expect(@request).to receive(:getSession).with(true).and_return @session
      expect(@session).to receive(:setAttribute).with(
        CGI::Session::JavaServletStore::RAILS_SESSION_KEY,
        an_instance_of(Java::byte[]))
      session_store.close
    end
  end

  describe "#delete" do
    it "should invalidate the servlet session" do
      expect(@request).to receive(:getSession).with(false).and_return @session
      expect(@session).to receive(:invalidate)
      session_store.delete
    end

    it "should do nothing if no session is established" do
      expect(@request).to receive(:getSession).with(false).and_return nil
      session_store.delete
    end
  end

  describe "#generate_digest" do
    before :each do
      expect(@request).to receive(:getSession).with(true).and_return @session
      @dbman = session_store
    end

    def hmac(key, data)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new("SHA1"), key, data)
    end

    it "should look for the secret in the java session" do
      expect(@session).to receive(:getAttribute).with("__rails_secret").and_return "secret"
      expect(@dbman.generate_digest("key")).to eq(hmac("secret", "key"))
    end

    it "should generate a secret from the java session id and last accessed time" do
      expect(OpenSSL::Random).to receive(:random_bytes).with(32).and_return "random"
      expect(@session).to receive(:getAttribute).with("__rails_secret").and_return nil
      expect(@session).to receive(:getId).and_return "abc"
      expect(@session).to receive(:getLastAccessedTime).and_return 123
      expect(@session).to receive(:setAttribute).with("__rails_secret", "abcrandom123")
      expect(@dbman.generate_digest("key")).to eq(hmac("abcrandom123", "key"))
    end
  end
end
