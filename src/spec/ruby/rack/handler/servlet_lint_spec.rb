#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))

require 'rack'
require 'rack/lint'
require 'uri'
require 'rack/handler/servlet'

# End-to-end conformance check: the env built from the servlet request and the
# handling of the (Lint wrapped) response must satisfy the loaded Rack version's
# SPEC - Rack::Lint raises when either side of the contract is broken.
describe 'Rack::Handler::Servlet (Rack::Lint)' do

  before :each do
    @servlet_context = mock_servlet_context
    allow(@rack_context).to receive(:getServerInfo).and_return 'Mock-Container/1.0'
    @servlet_request = org.springframework.mock.web.MockHttpServletRequest.new(@servlet_context)
    @servlet_response = org.springframework.mock.web.MockHttpServletResponse.new
    @servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(
      @servlet_request, @servlet_response, @rack_context
    )

    @servlet_request.setMethod('GET')
    @servlet_request.setContextPath('')
    @servlet_request.setRequestURI('/some/path')
    @servlet_request.setQueryString('a=1&b=2')
    @servlet_request.addParameter('a', '1')
    @servlet_request.addParameter('b', '2')
    @servlet_request.setServerName('lint.example.com')
    @servlet_request.setServerPort(8080)
    @servlet_request.setProtocol('HTTP/1.1')
    @servlet_request.setRemoteAddr('127.0.0.1')
    @servlet_request.setContent(''.to_java_bytes)
    @servlet_request.addHeader('Accept', 'text/plain')
  end

  let(:inner_app) do
    lambda do |env|
      env['rack.input'].read # exercises the Lint wrapped input contract
      if Rack.release >= '3'
        [ 200, { 'content-type' => 'text/plain' }, [ 'OK' ] ]
      else
        [ 200, { 'Content-Type' => 'text/plain', 'Content-Length' => '2' }, [ 'OK' ] ]
      end
    end
  end

  let(:servlet) { Rack::Handler::Servlet.new Rack::Lint.new(inner_app) }

  shared_examples 'lint-compatible env' do

    it "creates a SPEC compatible env and writes the response" do
      response = servlet.call(@servlet_env)
      expect(response.to_java.getStatus).to eql 200

      response_env = org.jruby.rack.servlet.ServletRackResponseEnvironment.new(@servlet_response)
      response.to_java.respond(response_env)
      expect(@servlet_response.getStatus).to eql 200
      expect(@servlet_response.getContentAsString).to eql 'OK'
    end

  end

  describe 'with (default) env' do
    it_behaves_like 'lint-compatible env'
  end

  describe 'with servlet env' do
    before { Rack::Handler::Servlet.env = :servlet }
    after { Rack::Handler::Servlet.env = nil }

    it_behaves_like 'lint-compatible env'
  end

end
