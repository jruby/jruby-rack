#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'jruby/rack/booter'

module JRuby::Rack
  class RailsBooter < Booter
    attr_reader :rails_env

    def initialize(rack_context = nil)
      super
      @rails_env = ENV['RAILS_ENV'] ||
        @rack_context.getInitParameter('rails.env') || rack_env || 'production'
    end

    def boot!
      super
      ENV['RAILS_ROOT'] = app_path
      ENV['RAILS_ENV'] = rails_env
      
      if File.exist?(File.join(app_path, "config", "application.rb"))
        require 'jruby/rack/rails/environment3'
        extend Rails3Environment
      else
        require 'jruby/rack/rails/environment2'
        extend Rails2Environment
      end
      
      set_relative_url_root
      set_public_root
      self
    end
    
    def default_layout_class
      klass = super
      klass == WebInfLayout ? RailsWebInfLayout : klass
    end
    
    protected
    
    def set_relative_url_root
      relative_url_append = @rack_context.getInitParameter('rails.relative_url_append') || ''
      relative_url_root = @rack_context.getContextPath + relative_url_append
      if ! relative_url_root.empty? && relative_url_root != '/'
        ENV['RAILS_RELATIVE_URL_ROOT'] = relative_url_root
      end
    end

    def set_public_root
      # NOOP by default - leave as it is
    end
    
    def load_extensions
      # no rack etc extensions required here (called during boot!)
      # require 'jruby/rack/rails/extensions' on #load_environment
    end
    
    public
    
    # @see #RailsRackApplicationFactory
    def self.load_environment
      rails_booter.load_environment
    end

    # @see #RailsRackApplicationFactory
    def self.to_app
      rails_booter.to_app
    end

    private

    def self.rails_booter
      raise "no booter set" unless booter = JRuby::Rack.booter
      raise "not a rails booter" unless booter.is_a?(JRuby::Rack::RailsBooter)
      booter
    end
    
  end
end
