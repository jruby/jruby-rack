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
    expect(@rack_context).to receive(:getRackFactory).at_least(1).and_return @rack_factory
    @dispatcher = org.jruby.rack.DefaultRackDispatcher.new @rack_context
  end

  describe "process" do

    it "retrieves a RackApplication and calls it" do
      application = double("application")
      request = double("request")
      response = double("response")
      rack_response = double("rack response")

      expect(@rack_factory).to receive(:getApplication).and_return(application)
      expect(@rack_factory).to receive(:finishedWithApplication).with(application)
      expect(application).to receive(:call).and_return rack_response
      expect(rack_response).to receive(:respond)

      @dispatcher.process(request, response)
    end

    it "stops processing on error if the response is already committed" do
      application = double("application")
      allow(@rack_factory).to receive(:getApplication).and_return application
      expect(@rack_factory).to receive(:finishedWithApplication).with application
      allow(application).to receive(:call).and_raise "some error"
      req, res = double("request"), double("response")
      allow(res).to receive(:isCommitted).and_return true
      @dispatcher.process(req, res)
    end

    context 'init error' do

      before do
        allow(@rack_factory).to receive(:getApplication).and_raise org.jruby.rack.RackInitializationException.new('fock')
        allow(@rack_factory).to receive(:getErrorApplication).and_return @error_app = double("error application")
      end

      it "lets the error application handle the error if the application could not be initialized" do
        req, res = double("request"), double("response")
        expect(req).to receive(:setAttribute).with(org.jruby.rack.RackEnvironment::EXCEPTION, anything())
        expect(res).to receive(:isCommitted).and_return false
        expect(res).to receive(:reset)
        rack_response = double "rack response"
        expect(@error_app).to receive(:call).and_return rack_response
        expect(rack_response).to receive(:respond)
        @dispatcher.process(req, res)
      end

      it "sends a 500 error if the error application can't successfully handle the error" do
        expect(@error_app).to receive(:call).and_raise "some error"

        req, res = double("request"), double("response")
        allow(req).to receive(:setAttribute)
        allow(res).to receive(:isCommitted).and_return false
        allow(res).to receive(:reset)

        expect(res).to receive(:sendError).with(500)
        @dispatcher.process(req, res)
      end

      it "allows the error app to re-throw a RackException" do
        expect(@error_app).to receive(:call) do
          raise org.jruby.rack.RackException.new('a rack exception')
        end

        req, res = double("request"), double("response")
        allow(req).to receive(:setAttribute)
        allow(res).to receive(:isCommitted).and_return false
        allow(res).to receive(:reset)
        expect(res).not_to receive(:sendError)

        expect { @dispatcher.process(req, res) }.to raise_error(org.jruby.rack.RackException)
      end

    end

  end

end