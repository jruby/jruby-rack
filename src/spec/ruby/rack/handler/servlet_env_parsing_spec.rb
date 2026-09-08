#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', File.dirname(__FILE__))

require 'rack'
require 'rack/handler/servlet'

# Differential coverage: the "pure" ServletEnv maps servlet-parsed parameters
# (HttpServletRequest#getParameterMap) into the Rack env, whereas DefaultEnv
# lets Rack itself parse the QUERY_STRING. ServletEnv's whole reason to exist
# is to produce the *same* params Rack would - so here we drive the same query
# string through both and assert Rack::Request#GET comes out identical.
#
# The decoded values handed to addParameter are written as literals (simulating
# what a servlet container decodes getParameterMap to), NOT computed via Rack's
# unescaper - otherwise the escaping comparison would be circular.
describe 'Rack::Handler::Servlet ServletEnv vs DefaultEnv (parsing parity)' do

  before do
    @servlet_context = mock_servlet_context
  end

  # Build Rack::Request#GET from a query string using the given env class.
  # +params+ are the (already url-decoded) name/value pairs the servlet
  # container would expose via getParameterMap; DefaultEnv ignores them.
  def get_params(env_class, query_string, params = [])
    request = org.springframework.mock.web.MockHttpServletRequest.new(@servlet_context)
    request.setMethod('GET')
    request.setRequestURI('/path')
    request.setQueryString(query_string)
    params.each { |name, value| request.addParameter(name, value) }
    response = org.springframework.mock.web.MockHttpServletResponse.new
    servlet_env = org.jruby.rack.servlet.ServletRackEnvironment.new(request, response, @rack_context)
    Rack::Request.new(env_class.create(servlet_env)).GET
  end

  DefaultEnv = Rack::Handler::Servlet::DefaultEnv
  ServletEnv = Rack::Handler::Servlet::ServletEnv

  # [ description, query_string, decoded getParameterMap pairs ]
  PARITY_CASES = [
    [ 'plain params',            'a=1&b=2',                 [ %w(a 1), %w(b 2) ] ],
    [ 'space via +',             'a=x+y',                   [ [ 'a', 'x y' ] ] ],
    [ 'space via %20',           'a=x%20y',                 [ [ 'a', 'x y' ] ] ],
    [ 'encoded & = #',           'a=%26%3D%23',             [ [ 'a', '&=#' ] ] ],
    [ 'encoded = in value',      'a=b%3Dc',                 [ [ 'a', 'b=c' ] ] ],
    [ 'utf-8 name and value',    'caf%C3%A9=%C3%BC',        [ [ "café", "ü" ] ] ],
    [ 'repeated flat key',       'a=1&a=2',                 [ %w(a 1), %w(a 2) ] ],
    [ 'array [] key',            'a%5B%5D=1&a%5B%5D=2',     [ [ 'a[]', '1' ], [ 'a[]', '2' ] ] ],
    [ 'hash [k] key',            'a%5Bb%5D=1',              [ [ 'a[b]', '1' ] ] ],
    [ 'deep [k][j] nesting',     'a%5Bb%5D%5Bc%5D=x',       [ [ 'a[b][c]', 'x' ] ] ],
    [ 'hash-in-array a[][b]',    'a%5B%5D%5Bb%5D=1',        [ [ 'a[][b]', '1' ] ] ],
    [ 'nested hash-in-array',    'book%5Bchapters%5D%5B%5D%5Btitle%5D=first&book%5Bchapters%5D%5B%5D%5Btitle%5D=second', [ [ 'book[chapters][][title]', 'first' ], [ 'book[chapters][][title]', 'second' ] ] ],
    [ 'numeric-index hash',      'huh%5B1%5D=b&huh%5B0%5D=a', [ [ 'huh[1]', 'b' ], [ 'huh[0]', 'a' ] ] ],
    [ 'bracket-in-bracket meh[]','foo%5Bmeh%5B%5D%5D=x&foo%5Bmeh%5B%5D%5D=42', [ [ 'foo[meh[]]', 'x' ], [ 'foo[meh[]]', '42' ] ] ],
    [ 'unbalanced brackets',     'foo]=0&bar[=1&baz_=2&[meh=3', [ [ 'foo]', '0' ], [ 'bar[', '1' ], [ 'baz_', '2' ], [ '[meh', '3' ] ] ],
    [ 'empty value',             'a=',                      [ [ 'a', '' ] ] ],
  ]
  # NOTE: not a parity case - ServletEnv intentionally does NOT treat ';' as a
  # value separator (getParameterMap keeps 'b;la'), whereas Rack 2.x's parser
  # still splits on ';'. See the ServletEnv-specific semicolon spec in
  # servlet_spec.rb. (Rack 3.x dropped ';' so it would be parity there.)

  PARITY_CASES.each do |desc, query_string, params|
    it "matches DefaultEnv (real Rack) for #{desc}" do
      default_get = get_params(DefaultEnv, query_string)
      servlet_get = get_params(ServletEnv, query_string, params)
      expect(servlet_get).to eq(default_get)
    end
  end

  it 'raises the same ParameterTypeError as Rack on a type clash' do
    # foo[]=0 then foo[bar]=1 - array then hash for the same name
    default_err = nil
    begin; get_params(DefaultEnv, 'foo%5B%5D=0&foo%5Bbar%5D=1'); rescue => e; default_err = e; end
    servlet_err = nil
    begin
      get_params(ServletEnv, 'foo%5B%5D=0&foo%5Bbar%5D=1', [ [ 'foo[]', '0' ], [ 'foo[bar]', '1' ] ])
    rescue => e
      servlet_err = e
    end

    expect(default_err).to be_a(::Rack::Utils::ParameterTypeError)
    expect(servlet_err).to be_a(::Rack::Utils::ParameterTypeError)
    expect(servlet_err.message).to eq(default_err.message)
  end

end
