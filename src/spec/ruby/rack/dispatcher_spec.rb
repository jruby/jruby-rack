#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')

describe org.jruby.rack.DefaultRackDispatcher do

  before :each do
    @rack_factory = org.jruby.rack.RackApplicationFactory.impl {}
    @rack_context.should_receive(:getRackFactory).at_least(1).and_return @rack_factory
    @dispatcher = org.jruby.rack.DefaultRackDispatcher.new @rack_context
  end

  describe "process" do

    it "retrieves a RackApplication and calls it" do
      application = double("application")
      request = double("request")
      response = double("response")
      rack_response = double("rack response")

      @rack_factory.should_receive(:getApplication).and_return(application)
      @rack_factory.should_receive(:finishedWithApplication).with(application)
      application.should_receive(:call).and_return rack_response
      rack_response.should_receive(:respond)

      @dispatcher.process(request, response)
    end

    it "stops processing on error if the response is already committed" do
      application = double("application")
      @rack_factory.stub(:getApplication).and_return application
      @rack_factory.should_receive(:finishedWithApplication).with application
      application.stub(:call).and_raise "some error"
      req, res = double("request"), double("response")
      res.stub(:isCommitted).and_return true
      @dispatcher.process(req, res)
    end

    context 'init error' do

      before do
        @rack_factory.stub(:getApplication).and_raise org.jruby.rack.RackInitializationException.new('fock')
        @rack_factory.stub(:getErrorApplication).and_return @error_app = double("error application")
      end

      it "lets the error application handle the error if the application could not be initialized" do
        req, res = double("request"), double("response")
        req.should_receive(:setAttribute).with(org.jruby.rack.RackEnvironment::EXCEPTION, anything())
        res.should_receive(:isCommitted).and_return false
        res.should_receive(:reset)
        rack_response = double "rack response"
        @error_app.should_receive(:call).and_return rack_response
        rack_response.should_receive(:respond)
        @dispatcher.process(req, res)
      end

      it "sends a 500 error if the error application can't successfully handle the error" do
        @error_app.should_receive(:call).and_raise "some error"

        req, res = double("request"), double("response")
        req.stub(:setAttribute)
        res.stub(:isCommitted).and_return false
        res.stub(:reset)

        res.should_receive(:sendError).with(500)
        @dispatcher.process(req, res)
      end

      it "allows the error app to re-throw a RackException" do
        @error_app.should_receive(:call) do
          raise org.jruby.rack.RackException.new('a rack exception')
        end

        req, res = double("request"), double("response")
        req.stub(:setAttribute)
        res.stub(:isCommitted).and_return false
        res.stub(:reset)
        res.should_not_receive(:sendError)

        expect( lambda {
            @dispatcher.process(req, res)
        } ).to raise_error(org.jruby.rack.RackException)
      end

    end

  end

end