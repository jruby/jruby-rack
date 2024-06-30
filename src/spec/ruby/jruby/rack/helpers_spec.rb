#--
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/helpers'

describe JRuby::Rack::Helpers do
  include JRuby::Rack::Helpers
  
  module A
    ENV = Object.new
    Some = :Some
    module B
      ENV = Object.new
      class SomeKlass < Object
        TRUE = 'TRUE'.freeze
      end
    end
  end
  
  it "constantizes from Object" do
    expect( constantize('ARGV') ).to be ARGV
    expect( constantize(:'Math::PI') ).to be ::Math::PI
  end

  it "constantizes using given context" do
    expect( constantize('ENV', A) ).to be A::ENV
    expect( constantize('ENV', A::B) ).to be A::B::ENV
  end
  
  it "constantizes using Object as context" do
    expect( constantize('ENV', Object) ).to be ::ENV
    expect( constantize('::ENV', A::B) ).to be ::ENV
  end

  it "constantizes (deeply) nested" do
    expect( constantize('A::B::SomeKlass') ).to be A::B::SomeKlass
  end
  it "constantizes nested with context" do
    expect( constantize('SomeKlass', A::B) ).to be A::B::SomeKlass
    expect( constantize('SomeKlass::TRUE', A::B) ).to be A::B::SomeKlass::TRUE
  end
  
  it "constantizes strictly" do
    expect { constantize('Some', A::B) }.to raise_error(NameError)
  end

  it "constantizes non-stricly from Object (parent) context" do
    expect( constantize('ARGV', A) ).to be ::ARGV
    expect( constantize('ARGV', A::B) ).to be ::ARGV
  end
  
  it "strips name on constantize" do
    expect( constantize(' Math::PI ') ).to be Math::PI
    expect( constantize(:'ARGV  ') ).to be ARGV
  end
  
  it "underscores" do
    expect( underscore("ServletLog") ).to eql 'servlet_log'
    expect( underscore("Rack::Handler::Servlet") ).to eql 'rack/handler/servlet'
    expect( underscore("Rack::Handler::Servlet::DefaultEnv") ).to eql 'rack/handler/servlet/default_env'
  end
  
  it "underscores (with built-in JRuby conversion by default) on successive capital cases" do
    expect( underscore(:"JRuby") ).to eql 'jruby'
    expect( underscore("JRuby::Rack::ServletLog") ).to eql 'jruby/rack/servlet_log'
    expect( underscore("Math::PI") ).to eql 'math/pi'
    expect( underscore("Math::PIANO") ).to eql 'math/piano'
    expect( underscore("Net::HTTP::SSLError") ).to eql 'net/http/ssl_error'
    expect( underscore("MOD::LONGCamelizedNameFORAll") ).to eql 'mod/long_camelized_name_for_all'
  end

  it "underscores (with built-in JRuby conversion by default) JRuby like" do
    expect( underscore("JRubyRack") ).to eql 'jruby_rack'
    expect( underscore("RackJRuby") ).to eql 'rack_j_ruby' # only if it starts
    expect( underscore("Nested::JRubyRack") ).to eql 'nested/jruby_rack'
    expect( underscore("Nested::RackJRuby") ).to eql 'nested/rack_j_ruby' # only if it starts
  end
  
  it "underscores without conversions" do
    expect( underscore("JRuby", false) ).to eql 'j_ruby'
    expect( underscore("JRuby::Rack::Response", nil) ).to eql 'j_ruby/rack/response'
    expect( underscore("Math::PI", {}) ).to eql 'math/pi'
    expect( underscore("Math::PIANO", nil) ).to eql 'math/piano'
    expect( underscore("Net::HTTP::SSLError", false) ).to eql 'net/http/ssl_error'
    expect( underscore("MOD::LONGCamelizedNameFORAll", false) ).to eql 'mod/long_camelized_name_for_all'
  end

  it "strips name on underscore" do
    expect( underscore(:" ServletLog ") ).to eql 'servlet_log'
    expect( underscore("  Rack::Handler::Servlet") ).to eql 'rack/handler/servlet'
  end
  
  it "resolves a constant" do
    expect( resolve_constant("JRuby::Rack::Helpers::Some") ).to be_a Class
    expect { resolve_constant("JRuby::Rack::Helpers::Missing") }.to raise_error NameError
    expect { resolve_constant("JRuby::Rack::Helpers::Another") }.to raise_error NameError
  end
  
end