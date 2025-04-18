#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/..')
require 'jruby/rack'

describe JRuby::Rack::Capture do

  before :each do
    JRuby::Rack.context = nil
    $servlet_context = @servlet_context
    allow(@servlet_context).to receive(:config).and_return Java::OrgJrubyRackEmbed::Config.new
  end

  it "captures environment information" do
    expect(@servlet_context).to receive(:log)
    error = StandardError.new "simulated rack start-up failed"
    error.capture
    error.store
    expect(error.output).to be_a StringIO
    expect(error.output.string).to include "An exception happened during JRuby-Rack startup"
    expect(error.output.string).to include "simulated rack start-up failed"
    expect(error.output.string).to include "--- System"
    expect(error.output.string).to include "jruby #{JRUBY_VERSION}"
    expect(error.output.string).to include "--- Context Init Parameters:"
    expect(error.output.string).to include "--- RubyGems"
    expect(error.output.string).to include "Gem.path:"
    expect(error.output.string).to include "--- Bundler"
    expect(error.output.string).to include "Gemfile:"
    if JRUBY_VERSION.start_with?("9.")
      expect(error.output.string).to include "--- JRuby-Rack Config"
      expect(error.output.string).to include "logger_class_name"
    else
      # This is disabled on JRuby 10 to avoid CompatVersion missing class issues without breaking backward compat
      expect(error.output.string).not_to include "--- JRuby-Rack Config"
    end
  end

  it "captures exception backtrace" do
    begin
      raise ZeroDivisionError.new
    rescue ZeroDivisionError => e
      e.capture
      expect(e.output.string).to match /--- Backtrace/
      expect(e.output.string).to match /ZeroDivisionError/
    end
  end

end
