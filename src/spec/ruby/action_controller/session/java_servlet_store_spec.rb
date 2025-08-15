require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe "ActionController::Session::JavaServletStore" do

  before :all do
    require 'active_support'
    require 'action_controller'
    require 'action_controller/session/java_servlet_store'
    require 'jruby/rack/session_store'
  end

  before :each do
    @session = double "servlet session"
    allow(@session).to receive(:getId).and_return @session_id = "random-session-id"
    allow(@session).to receive(:getAttribute).and_return nil
    allow(@session).to receive(:getAttributeNames).and_return []
    allow(@session).to receive(:synchronized).and_yield
    @request = double "servlet request"
    @app = double "app"
    allow(@app).to receive(:call).and_return [200, {}, ["body"]]
    @env = { "java.servlet_request" => @request, "rack.errors" => $stderr }
    @session_store = ActionController::Session::JavaServletStore.new(@app)
  end

  it "should do nothing if the session is not accessed" do
    expect(@app).to receive(:call)
    @session_store.call(@env)
  end

  it "should report session not loaded if not accessed" do
    expect(@app).to receive(:call)
    @session_store.call(@env)
    session = @env['rack.session']
    expect(@session_store.send(:loaded_session?, session)).to eq false
  end

  it "should pass the application response untouched" do
    response = [200, {}, ["body"]]
    expect(@app).to receive(:call).and_return response
    expect(@session_store.call(@env)).to eq response
  end

  it "should load the session when accessed" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo']
    end
    @session_store.call(@env)
    expect(@env['rack.session']).not_to be nil
    expect(@env['rack.session.options']).not_to be nil
    if defined? ::Rack::Session::Abstract::OptionsHash
      expect(@env['rack.session.options'][:id]).not_to be nil
    else
      expect(@env['rack.session'].loaded?).to be true
    end
  end

  it "should report session loaded when accessed" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo']
    end
    @session_store.call(@env)
    session = @env['rack.session']
    expect(@session_store.send(:loaded_session?, session)).to eq true
  end

  it "should use custom session hash when loading session" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      env['rack.session']["foo"] = "bar"
    end
    @session_store.call(@env)
    expect(@env['rack.session']).to be_instance_of(JRuby::Rack::Session::SessionHash)
  end

  it "should extract session id" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    expect(@app).to receive(:call)
    @session_store.call(@env)
    expect(@session_store.send(:extract_session_id, Rack::Request.new(@env))).to eq @session_id
  end

  it "should retrieve the marshalled session from the java session" do
    hash = { "foo" => 1, "bar" => true }
    marshal_data = Marshal.dump hash
    expect(@request).to receive(:getSession).with(false).and_return @session
    session_key = ActionController::Session::JavaServletStore::RAILS_SESSION_KEY
    expect(@session).to receive(:getAttributeNames).and_return [session_key]
    expect(@session).to receive(:getAttribute).with(session_key).and_return marshal_data.to_java_bytes
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      expect(env['rack.session']["foo"]).to eq 1
      expect(env['rack.session']["bar"]).to eq true
    end
    @session_store.call(@env)
  end

  it "should retrieve values from other keys in the session" do
    hash = { "foo" => 1, "bar" => true }
    expect(@request).to receive(:getSession).with(false).and_return @session
    expect(@session).to receive(:getAttributeNames).and_return ["foo", "bar"]
    expect(@session).to receive(:getAttribute).with("foo").and_return hash["foo"]
    expect(@session).to receive(:getAttribute).with("bar").and_return hash["bar"]
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      expect(env['rack.session']["foo"]).to eq hash["foo"]
      expect(env['rack.session']["bar"]).to eq hash["bar"]
    end
    @session_store.call(@env)
  end

  it "should retrieve java objects in the session" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    expect(@session).to receive(:getAttributeNames).and_return ["foo"]
    expect(@session).to receive(:getAttribute).with("foo").and_return java.lang.Object.new
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@app).to receive(:call) do |env|
      expect(env['rack.session']["foo"]).to be_kind_of(java.lang.Object)
    end
    @session_store.call(@env)
  end

  it "should marshal the session to the java session" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:getAttribute).and_return nil; allow(@session).to receive(:getCreationTime).and_return 1
    expect(@session).to receive(:setAttribute).with(ActionController::Session::JavaServletStore::RAILS_SESSION_KEY,
                                                    an_instance_of(Java::byte[]))
    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo'] = Object.new
    end
    @session_store.call(@env)
  end

  it "should create the session if it doesn't exist" do
    expect(@request).to receive(:getSession).with(false).ordered.at_most(:twice).and_return nil
    expect(@request).to receive(:getSession).with(true).ordered.and_return @session
    expect(@session).to receive(:setAttribute).with(ActionController::Session::JavaServletStore::RAILS_SESSION_KEY,
                                                    an_instance_of(Java::byte[]))
    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo'] = Object.new
    end
    @session_store.call(@env)
  end

  it "should store entries with string keys and values as java session attributes" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@session).to receive(:setAttribute).with("foo", "bar")
    expect(@app).to receive(:call) do |env|
      env['rack.session']["foo"] = "bar"
    end
    @session_store.call(@env)
  end

  it "should store numeric or boolean values as java session attributes" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@session).to receive(:setAttribute).with("foo", true)
    expect(@session).to receive(:setAttribute).with("bar", 20)
    expect(@session).to receive(:setAttribute).with("baz", false)
    expect(@app).to receive(:call) do |env|
      env['rack.session']["foo"] = true
      env['rack.session']["bar"] = 20
      env['rack.session']["baz"] = false
    end
    @session_store.call(@env)
  end

  it "should store java object values as java session attributes" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@session).to receive(:setAttribute).with("foo", an_instance_of(java.lang.Object))
    expect(@app).to receive(:call) do |env|
      env['rack.session']["foo"] = java.lang.Object.new
    end
    @session_store.call(@env)
  end

  it "should remove keys that are not present at the end of the request 007" do
    allow(@request).to receive(:getSession).and_return @session
    allow(@session).to receive(:getAttributeNames).and_return ["foo", "bar", "baz"]
    allow(@session).to receive(:setAttribute); allow(@session).to receive(:getCreationTime).and_return 1
    expect(@session).to receive(:removeAttribute).with("foo")
    expect(@session).to receive(:removeAttribute).with("baz")
    expect(@app).to receive(:call) do |env|
      env['rack.session'].delete('foo')
      env['rack.session']['baz'] = nil
      env['rack.session']['bar'] = 'x'
    end
    @session_store.call(@env)
  end

  it "should invalidate the servlet session" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    allow(@session).to receive(:getId).and_return(nil)
    expect(@session).to receive(:invalidate).ordered
    expect(@app).to receive(:call) do |env|
      env['rack.session.options'].delete(:id)
      # env['rack.session'] = new_session_hash(env)
      env['rack.session'].send :load!
    end
    @session_store.call(@env)
  end

  it "should attempt to invalidate an invalid servlet session" do
    session = double_http_session; session.invalidate
    expect(@request).to receive(:getSession).with(false).and_return session

    expect(@app).to receive(:call) do |env|
      env['rack.session.options'].delete(:id)
      env['rack.session'].send :load!
    end
    expect { @session_store.call(@env) }.to_not raise_error
  end

  it "should handle session with an invalid servlet session" do
    session = double_http_session; session.invalidate
    # NOTE by attempting to create a new one -
    # or should we drop in this case ?! (since no :renew session option passed)
    expect(@request).to receive(:getSession).ordered.
      with(false).and_return session
    expect(@request).to receive(:getSession).ordered.
      with(true).and_return new_session = double_http_session

    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo'] = 'bar'
    end
    @session_store.call(@env)
  end

  it "should do nothing on session reset if no session is established" do
    expect(@request).to receive(:getSession).with(false).and_return nil
    expect(@app).to receive(:call) do |env|
      env['rack.session.options'].delete(:id)
      env['rack.session'] = new_session_hash(env) # not loaded?
    end
    @session_store.call(@env)
  end

  it "should forward calls that look like they're directed at the java servlet session" do
    time = Time.now.to_i * 1000
    expect(@request).to receive(:getSession).and_return @session
    expect(@session).to receive(:getLastAccessedTime).and_return time
    allow(@session).to receive(:setAttribute)
    expect(@app).to receive(:call) do |env|
      expect(env['rack.session'].getLastAccessedTime).to eq time
      expect { env['rack.session'].blah_blah }.to raise_error(NoMethodError)
    end
    @session_store.call(@env)
  end

  it "supports renewing a session" do
    session = double_http_session
    expect(@request).to receive(:getSession).ordered.with(false).and_return(session)

    new_session = double_http_session
    expect(@request).to receive(:getSession).ordered.with(true).and_return(new_session)

    expect(@app).to receive(:call) do |env|
      env['rack.session.options'] = { :id => session.id, :renew => true, :defer => true }
      env['rack.session']['_csrf_token'] = 'v3PrzsdkWug9Q3xCthKkEzUMbZSzgQ9Bt+43lH0bEF8='
    end
    @session_store.call(@env)

    expect(session.isInvalid).to be true

    expect(new_session.isInvalid).to be false
    expect(new_session.send(:getAttribute, "_csrf_token")).to_not be nil
  end

  it "propagates rails csrf token to session during commit" do
    skip "Only runs on Rails 7.1+" unless defined? ::ActionController::RequestForgeryProtection::CSRF_TOKEN
    session = double_http_session
    expect(@request).to receive(:getSession).and_return(session)

    expect(@app).to receive(:call) do |env|
      env['rack.session']['foo'] = 'bar'
      env[::ActionController::RequestForgeryProtection::CSRF_TOKEN] = 'some_token'
    end
    @session_store.call(@env)

    # CSRF token propagated from env to underlying session
    expect(session.send(:getAttribute, '_csrf_token')).to eq 'some_token'
    expect(session.send(:getAttribute, 'foo')).to eq 'bar'
  end

  it "handles the skip session option" do
    expect(@request).to receive(:getSession).with(false).and_return @session
    expect(@session).not_to receive(:setAttribute)
    expect(@app).to receive(:call) do |env|
      env['rack.session.options'][:skip] = true
      env['rack.session']['foo'] = 'bar'
    end
    expect { @session_store.call(@env) }.to_not raise_error
  end

  private

  def double_http_session
    Java::OrgSpringframeworkMockWeb::MockHttpSession.new
  end

  def new_session_hash(*args)
    if args.size > 1
      store = args[0]; env = args[1];
    else
      store = @session_store; env = args[0];
    end
    ::JRuby::Rack::Session::SessionHash.new(store, ::Rack::Request.new(env))
  end

end if defined? Rails
