require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe "ActionController::Session::JavaServletStore" do

  before :all do

    require 'active_support'
    require 'action_controller'
    begin # help Rails 3.0 up
      require 'action_dispatch/middleware/session/abstract_store'
    rescue LoadError
    end
    begin # a Rails 2.3 require
      require 'action_controller/session/abstract_store'
    rescue LoadError
    end

    require 'jruby/rack/session_store'

    require 'action_controller/session/java_servlet_store'
  end

  before :each do
    @session = double "servlet session"
    @session.stub(:getId).and_return @session_id = "random-session-id"
    @session.stub(:getAttribute).and_return nil
    @session.stub(:getAttributeNames).and_return []
    @session.stub(:synchronized).and_yield
    @request = double "servlet request"
    @app = double "app"
    @env = {"java.servlet_request" => @request, "rack.errors" => $stderr}
    @session_store = ActionController::Session::JavaServletStore.new(@app)
  end

  it "should raise an error if the servlet request is not present" do
    lambda { @session_store.call({}) }.should raise_error
  end

  it "should do nothing if the session is not accessed" do
    @app.should_receive(:call)
    @session_store.call(@env)
  end

  it "should report session not loaded if not accessed" do
    @app.should_receive(:call)
    @session_store.call(@env)
    session = @env['rack.session']
    @session_store.send(:loaded_session?, session).should == false
  end

  it "should pass the application response untouched" do
    response = [200, {}, ["body"]]
    @app.should_receive(:call).and_return response
    @session_store.call(@env).should == response
  end

  it "should load the session when accessed" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']['foo']
    end
    @session_store.call(@env)
    @env['rack.session'].should_not be nil
    @env['rack.session.options'].should_not be nil
    if defined? ::Rack::Session::Abstract::OptionsHash
      @env['rack.session.options'][:id].should_not be nil
    else
      @env['rack.session'].loaded?.should be true
    end
  end

  it "should report session loaded when accessed" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']['foo']
    end
    @session_store.call(@env)
    session = @env['rack.session']
    @session_store.send(:loaded_session?, session).should == true
  end

  it "should use custom session hash when loading session" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"] = "bar"
    end
    @session_store.call(@env)
    @env['rack.session'].should be_instance_of JRuby::Rack::Session::SessionHash
  end

  it "should extract session id" do
    @request.should_receive(:getSession).with(false).and_return @session
    @app.should_receive(:call)
    @session_store.call(@env)
    @session_store.send(:extract_session_id, @env).should == @session_id
  end

  it "should retrieve the marshalled session from the java session" do
    hash = {"foo" => 1, "bar" => true}
    marshal_data = Marshal.dump hash
    @request.should_receive(:getSession).with(false).and_return @session
    session_key = ActionController::Session::JavaServletStore::RAILS_SESSION_KEY
    @session.should_receive(:getAttributeNames).and_return [session_key]
    @session.should_receive(:getAttribute).with(session_key).and_return marshal_data.to_java_bytes
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"].should == 1
      env['rack.session']["bar"].should == true
    end
    @session_store.call(@env)
  end

  it "should retrieve values from other keys in the session" do
    hash = {"foo" => 1, "bar" => true}
    @request.should_receive(:getSession).with(false).and_return @session
    @session.should_receive(:getAttributeNames).and_return ["foo", "bar"]
    @session.should_receive(:getAttribute).with("foo").and_return hash["foo"]
    @session.should_receive(:getAttribute).with("bar").and_return hash["bar"]
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"].should == hash["foo"]
      env['rack.session']["bar"].should == hash["bar"]
    end
    @session_store.call(@env)
  end

  it "should retrieve java objects in the session" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.should_receive(:getAttributeNames).and_return ["foo"]
    @session.should_receive(:getAttribute).with("foo").and_return java.lang.Object.new
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"].should be_kind_of(java.lang.Object)
    end
    @session_store.call(@env)
  end

  it "should marshal the session to the java session" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:getAttribute).and_return nil; @session.stub(:getCreationTime).and_return 1
    @session.should_receive(:setAttribute).with(ActionController::Session::JavaServletStore::RAILS_SESSION_KEY,
                                                an_instance_of(Java::byte[]))
    @app.should_receive(:call).and_return do |env|
      env['rack.session']['foo'] = Object.new
    end
    @session_store.call(@env)
  end

  it "should create the session if it doesn't exist" do
    @request.should_receive(:getSession).with(false).ordered.at_most(:twice).and_return nil
    @request.should_receive(:getSession).with(true).ordered.and_return @session
    @session.should_receive(:setAttribute).with(ActionController::Session::JavaServletStore::RAILS_SESSION_KEY,
                                                an_instance_of(Java::byte[]))
    @app.should_receive(:call).and_return do |env|
      env['rack.session']['foo'] = Object.new
    end
    @session_store.call(@env)
  end

  it "should store entries with string keys and values as java session attributes" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @session.should_receive(:setAttribute).with("foo", "bar")
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"] = "bar"
    end
    @session_store.call(@env)
  end

  it "should store numeric or boolean values as java session attributes" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @session.should_receive(:setAttribute).with("foo", true)
    @session.should_receive(:setAttribute).with("bar", 20)
    @session.should_receive(:setAttribute).with("baz", false)
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"] = true
      env['rack.session']["bar"] = 20
      env['rack.session']["baz"] = false
    end
    @session_store.call(@env)
  end

  it "should store java object values as java session attributes" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @session.should_receive(:setAttribute).with("foo", an_instance_of(java.lang.Object))
    @app.should_receive(:call).and_return do |env|
      env['rack.session']["foo"] = java.lang.Object.new
    end
    @session_store.call(@env)
  end

  it "should remove keys that are not present at the end of the request 007" do
    @request.stub(:getSession).and_return @session
    @session.stub(:getAttributeNames).and_return ["foo", "bar", "baz"]
    @session.stub(:setAttribute); @session.stub(:getCreationTime).and_return 1
    @session.should_receive(:removeAttribute).with("foo")
    @session.should_receive(:removeAttribute).with("baz")
    @app.should_receive(:call).and_return do |env|
      env['rack.session'].delete('foo')
      env['rack.session']['baz'] = nil
      env['rack.session']['bar'] = 'x'
    end
    @session_store.call(@env)
  end

  it "should invalidate the servlet session" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.stub(:getId).and_return(nil)
    @session.should_receive(:invalidate).ordered
    @app.should_receive(:call).and_return do |env|
      env['rack.session.options'].delete(:id)
      #env['rack.session'] = new_session_hash(env)
      env['rack.session'].send :load!
    end
    @session_store.call(@env)
  end

  it "should attempt to invalidate an invalid servlet session" do
    session = double_http_session(nil); session.invalidate
    @request.should_receive(:getSession).with(false).and_return session

    @app.should_receive(:call).and_return do |env|
      env['rack.session.options'].delete(:id)
      env['rack.session'].send :load!
    end
    expect( lambda { @session_store.call(@env) } ).to_not raise_error
  end

  it "should handle session with an invalid servlet session" do
    session = double_http_session; session.invalidate
    # NOTE by attempting to create a new one -
    # or should we drop in this case ?! (since no :renew session option passed)
    @request.should_receive(:getSession).ordered.
      with(false).and_return session
    @request.should_receive(:getSession).ordered.
      with(true).and_return new_session = double_http_session

    @app.should_receive(:call).and_return do |env|
      env['rack.session']['foo'] = 'bar'
    end
    @session_store.call(@env)
  end

  it "should do nothing on session reset if no session is established" do
    @request.should_receive(:getSession).with(false).and_return nil
    @app.should_receive(:call).and_return do |env|
      env['rack.session.options'].delete(:id)
      env['rack.session'] = new_session_hash(env) # not loaded?
    end
    @session_store.call(@env)
  end

  it "should forward calls that look like they're directed at the java servlet session" do
    time = Time.now.to_i*1000
    @request.should_receive(:getSession).and_return @session
    @session.should_receive(:getLastAccessedTime).and_return time
    @session.stub(:setAttribute)
    @app.should_receive(:call).and_return do |env|
      env['rack.session'].getLastAccessedTime.should == time
      lambda { env['rack.session'].blah_blah }.should raise_error(NoMethodError)
    end
    @session_store.call(@env)
  end

  it "supports renewing a session" do
    session = double_http_session sid = "EC72C9F8EC984052C6F13D08893121DF"
    @request.should_receive(:getSession).ordered.with(false).and_return(session)

    new_session = double_http_session
    @request.should_receive(:getSession).ordered.with(true).and_return(new_session)

    @app.should_receive(:call).and_return do |env|
      env['rack.session.options'] = { :id => sid, :renew => true, :defer => true }
      env['rack.session']['_csrf_token'] = 'v3PrzsdkWug9Q3xCthKkEzUMbZSzgQ9Bt+43lH0bEF8='
    end
    @session_store.call(@env)

    expect( session.isInvalid ).to be true
    attrs = session.send(:getAttributes)
    expect( attrs['_csrf_token'] ).to be nil

    expect( new_session.isInvalid ).to be false
    attrs = new_session.send(:getAttributes)
    expect( attrs['_csrf_token'] ).to_not be nil
  end

  it "handles the skip session option" do
    @request.should_receive(:getSession).with(false).and_return @session
    @session.should_not_receive(:setAttribute)
    @app.should_receive(:call).and_return do |env|
      env['rack.session.options'][:skip] = true
      env['rack.session']['foo'] = 'bar'
    end
    expect( lambda { @session_store.call(@env) } ).to_not raise_error
  end

  private

  def double_http_session(id = false)
    session = Java::OrgJrubyRackMock::MockHttpSession.new
    session.send(:setId, id) if id != false
    session
  end

  def new_session_hash(*args)
    if args.size > 1
      store = args[0]; env = args[1];
    else
      store = @session_store; env = args[0];
    end
    ::JRuby::Rack::Session::SessionHash.new(store, env)
  end

end if defined? Rails