#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')
require 'jruby/rack/booter'

describe JRuby::Rack::Booter do

  let(:booter) do
    JRuby::Rack::Booter.new JRuby::Rack.context = @rack_context
  end

  after(:all) { JRuby::Rack.context = nil }

  before do
    @rack_env = ENV['RACK_ENV']
    @gem_path = Gem.path.to_a
    @env_gem_path = ENV['GEM_PATH']
  end

  after do
    @rack_env.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = @rack_env
    Gem.path.replace(@gem_path)
    @env_gem_path.nil? ? ENV.delete('GEM_PATH') : ENV['GEM_PATH'] = @env_gem_path
  end

  it "should determine the public html root from the 'public.root' init parameter" do
    expect(@rack_context).to receive(:getInitParameter).with("public.root").and_return "/blah"
    expect(@rack_context).to receive(:getRealPath).with("/blah").and_return "."
    booter.boot!
    expect(booter.public_path).to eq "."
  end

  it "should convert public.root to not have any trailing slashes" do
    expect(@rack_context).to receive(:getInitParameter).with("public.root").and_return "/blah/"
    expect(@rack_context).to receive(:getRealPath).with("/blah").and_return "/blah/blah"
    booter.boot!
    expect(booter.public_path).to eq "/blah/blah"
  end

  it "should default public root to '/'" do
    expect(@rack_context).to receive(:getRealPath).with("/").and_return "."
    booter.boot!
    expect(booter.public_path).to eq "."
  end

  it "should chomp trailing slashes from paths" do
    expect(@rack_context).to receive(:getRealPath).with("/").and_return "/hello/there/"
    booter.boot!
    expect(booter.public_path).to eq "/hello/there"
  end

  it "should determine the gem path from the gem.path init parameter" do
    expect(@rack_context).to receive(:getInitParameter).with("gem.path").and_return "/blah"
    expect(@rack_context).to receive(:getRealPath).with("/blah").and_return "./blah"
    booter.boot!
    expect(booter.gem_path).to eq "./blah"
  end

  it "should also be able to determine the gem path from the gem.home init parameter" do
    expect(@rack_context).to receive(:getInitParameter).with("gem.home").and_return "/blah"
    expect(@rack_context).to receive(:getRealPath).with("/blah").and_return "/home/kares/blah"
    booter.boot!
    expect(booter.gem_path).to eq "/home/kares/blah"
  end

  it "defaults gem path to '/WEB-INF/gems'" do
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "file:/home/kares/WEB-INF"
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF/gems").and_return "file:/home/kares/WEB-INF/gems"
    booter.boot!
    expect(booter.gem_path).to eq "file:/home/kares/WEB-INF/gems"
  end

  it "gets rack environment from rack.env" do
    ENV.delete('RACK_ENV')
    expect(@rack_context).to receive(:getInitParameter).with("rack.env").and_return "staging"
    booter.boot!
    expect(booter.rack_env).to eq 'staging'
  end

  it "gets rack environment from ENV" do
    ENV['RACK_ENV'] = 'production'
    allow(@rack_context).to receive(:getInitParameter)
    booter.boot!
    expect(booter.rack_env).to eq 'production'
  end

  it "prepends gem_path to Gem.path (when configured to not mangle with ENV)" do
    expect(@rack_context).to receive(:getInitParameter).with("jruby.rack.env.gem_path").and_return 'false'
    Gem.path.replace ['/opt/gems']
    booter.gem_path = "wsjar:file:/opt/deploy/sample.war!/WEB-INF/gems"
    booter.boot!

    expect(Gem.path).to eql ['wsjar:file:/opt/deploy/sample.war!/WEB-INF/gems', '/opt/gems']
  end

  it "prepends gem_path to Gem.path if not already present" do
    Gem.path.replace ["file:/home/gems", "/usr/local/gems"]
    booter.gem_path = '/usr/local/gems'
    booter.boot!

    expect(Gem.path).to eql ["file:/home/gems", "/usr/local/gems"]
  end

  it "does not change Gem.path if gem_path empty" do
    Gem.path.replace ['/opt/gems']
    booter.gem_path = ""
    booter.boot!

    expect(Gem.path).to eql ['/opt/gems']
  end

  it "prepends gem_path to ENV['GEM_PATH'] if jruby.rack.gem_path set to true" do
    expect(@rack_context).to receive(:getInitParameter).with("jruby.rack.env.gem_path").and_return 'true'
    ENV['GEM_PATH'] = '/opt/gems'
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "/opt/deploy/sample.war!/WEB-INF"
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF/gems").and_return "/opt/deploy/sample.war!/WEB-INF/gems"

    booter.boot!

    expect(ENV['GEM_PATH']).to eq "/opt/deploy/sample.war!/WEB-INF/gems#{File::PATH_SEPARATOR}/opt/gems"
  end

  it "does not prepend gem_path to ENV['GEM_PATH'] if jruby.rack.gem_path set not set" do
    expect(@rack_context).to receive(:getInitParameter).with("jruby.rack.env.gem_path").and_return ''
    ENV['GEM_PATH'] = '/opt/gems'
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "/opt/deploy/sample.war!/WEB-INF"
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF/gems").and_return "/opt/deploy/sample.war!/WEB-INF/gems"

    booter.boot!

    expect(ENV['GEM_PATH']).to eq "/opt/gems"
  end

  it "prepends gem_path to ENV['GEM_PATH'] if not already present" do
    ENV['GEM_PATH'] = "/home/gems#{File::PATH_SEPARATOR}/usr/local/gems"
    booter.gem_path = '/usr/local/gems'
    booter.boot!

    expect(ENV['GEM_PATH']).to eq "/home/gems#{File::PATH_SEPARATOR}/usr/local/gems"
  end

  it "sets ENV['GEM_PATH'] to the value of gem_path if ENV['GEM_PATH'] is not present" do
    expect(@rack_context).to receive(:getInitParameter).with("jruby.rack.env.gem_path").and_return 'true'
    ENV.delete('GEM_PATH')
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF").and_return "/blah"
    expect(@rack_context).to receive(:getRealPath).with("/WEB-INF/gems").and_return "/blah/gems"

    booter.boot!

    expect(ENV['GEM_PATH']).to eq "/blah/gems"
  end

  it "creates a logger that writes messages to the servlet context (by default)" do
    booter.boot!
    allow(@rack_context).to receive(:isEnabled).and_return true
    level = org.jruby.rack.RackLogger::Level::DEBUG
    expect(@rack_context).to receive(:log).with(level, 'Hello-JRuby!')
    booter.logger.debug 'Hello-JRuby!'
  end

  before { $loaded_init_rb = nil }

  it "loads and executes ruby code in META-INF/init.rb if it exists" do
    expect(@rack_context).to receive(:getResource).with("/META-INF/init.rb").
      and_return java.net.URL.new("file:#{File.expand_path('init.rb', STUB_DIR)}")
    silence_warnings { booter.boot! }
    expect($loaded_init_rb).to eq true
    expect(defined?(::SOME_TOPLEVEL_CONSTANT)).to eq "constant"
  end

  it "loads and executes ruby code in WEB-INF/init.rb if it exists" do
    expect(@rack_context).to receive(:getResource).with("/WEB-INF/init.rb").
      and_return java.net.URL.new("file://#{File.expand_path('init.rb', STUB_DIR)}")
    silence_warnings { booter.boot! }
    expect($loaded_init_rb).to eq true
  end

  it "delegates _path methods to layout" do
    expect(booter).to receive(:layout).at_least(:once).and_return layout = double('layout')
    expect(layout).to receive(:app_path).and_return 'app/path'
    expect(layout).to receive(:gem_path).and_return 'gem/path'
    expect(layout).to receive(:public_path).and_return 'public/path'

    expect(booter.app_path).to eq 'app/path'
    expect(booter.gem_path).to eq 'gem/path'
    expect(booter.public_path).to eq 'public/path'
  end

  it "changes working directory to app path on boot" do
    wd = Dir.pwd
    begin
      allow(booter).to receive(:layout).and_return layout = double('layout')
      allow(layout).to receive(:app_path).and_return parent = File.expand_path('..')
      allow(layout).to receive(:gem_path)
      allow(layout).to receive(:public_path)

      booter.boot!
      expect(Dir.pwd).to eq parent
    ensure
      Dir.chdir(wd)
    end
  end

  it "does not raise when changing working directory fails" do
    # NOTE: on IBM WebSphere (8.5 Liberty Profile) `Dir.chdir` fails e.g. :
    #  (Errno::ENOENT) /opt/apps/wlp/usr/servers/defaultServer/dropins/bug-demo.war!/WEB-INF
    #    at org.jruby.RubyDir.chdir(org/jruby/RubyDir.java:352)
    #    at RUBY.change_working_directory(classpath:/jruby/rack/booter.rb:125)
    #    at RUBY.boot!(classpath:/jruby/rack/booter.rb:105)
    #    at RUBY.(root)(classpath:/jruby/rack/boot/rack.rb:10)
    app_dir = "#{File.absolute_path Dir.pwd}/sample.war!/WEB-INF"
    allow(File).to receive(:directory?).with(app_dir).and_return true
    allow(booter).to receive(:layout).and_return layout = double('layout')
    allow(layout).to receive(:app_path).and_return app_dir
    allow(layout).to receive(:gem_path)
    allow(layout).to receive(:public_path)

    booter.boot! # expect to_not raise_error
  end

  context "within a runtime" do

    describe "rack env" do

      before :each do
        # NOTE: this is obviously poor testing but it's easier to let the factory
        # setup the runtime for us than to hand copy/stub/mock all code involved
        servlet_context = javax.servlet.ServletContext.impl do |name, *args|
          case name.to_sym
          when :getRealPath then
            case args.first
            when '/WEB-INF' then File.expand_path('rack/WEB-INF', STUB_DIR)
            end
          when :getContextPath then
            '/'
          when :log then
            raise_logger.log(*args)
          else nil
          end
        end
        rack_config = org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
        rack_context = org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
        app_factory = org.jruby.rack.DefaultRackApplicationFactory.new
        app_factory.init rack_context

        @runtime = app_factory.newRuntime
        @runtime.evalScriptlet("ENV.clear")
      end

      it "sets up (default) rack booter and boots" do
        # DefaultRackApplicationFactory#createApplicationObject
        @runtime.evalScriptlet("load 'jruby/rack/boot/rack.rb'")

        # booter got setup :
        should_not_eval_as_nil "defined?(JRuby::Rack.booter)"
        should_not_eval_as_nil "JRuby::Rack.booter"
        should_eval_as_eql_to "JRuby::Rack.booter.class.name", 'JRuby::Rack::Booter'

        # Booter.boot! run :
        should_not_eval_as_nil "ENV['RACK_ENV']"
        # rack got required :
        should_not_eval_as_nil "defined?(Rack::VERSION)"
        should_not_eval_as_nil "defined?(Rack.release)"
        # check if it got loaded correctly :
        should_not_eval_as_nil "Rack::Request.new({}) rescue nil"
      end

    end

    describe "rails env" do

      before :each do
        # NOTE: this is obviously poor testing but it's easier to let the factory
        # setup the runtime for us than to hand copy/stub/mock all code involved
        servlet_context = javax.servlet.ServletContext.impl do |name, *args|
          case name.to_sym
          when :getRealPath then
            case args.first
            when '/WEB-INF' then File.expand_path('rails30/WEB-INF', STUB_DIR)
            end
          when :getContextPath then
            '/'
          when :log then
            raise_logger.log(*args)
          else nil
          end
        end
        rack_config = org.jruby.rack.servlet.ServletRackConfig.new(servlet_context)
        rack_context = org.jruby.rack.servlet.DefaultServletRackContext.new(rack_config)
        app_factory = org.jruby.rack.rails.RailsRackApplicationFactory.new
        app_factory.init rack_context

        @runtime = app_factory.newRuntime
        @runtime.evalScriptlet("ENV.clear")
      end

      it "sets up rails booter and boots" do
        # RailsRackApplicationFactory#createApplicationObject
        @runtime.evalScriptlet("load 'jruby/rack/boot/rails.rb'")

        # booter got setup :
        should_not_eval_as_nil "defined?(JRuby::Rack.booter)"
        should_not_eval_as_nil "JRuby::Rack.booter"
        should_eval_as_eql_to "JRuby::Rack.booter.class.name", 'JRuby::Rack::RailsBooter'

        # Booter.boot! run :
        should_not_eval_as_nil "ENV['RACK_ENV']"
        should_not_eval_as_nil "ENV['RAILS_ENV']"

        # rack not yet required (let bundler decide which rack version to load) :
        should_eval_as_nil "defined?(Rack::VERSION)"
        should_eval_as_nil "defined?(Rack.release)"
      end

    end

  end

end
