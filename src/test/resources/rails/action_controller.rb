#--
# Copyright 2007-2008 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

#--
# Stubbed out Rails classes for testing
#++

module ActionController
  class Base
    class << self
      attr_accessor :page_cache_directory, :session_store
    end
  end
  
  class CgiRequest
    DEFAULT_SESSION_OPTIONS = {}
  end
end

module ActionView
  class Base
    class << self
      attr_accessor :cache_template_loading
    end
  end
  module Helpers
    module AssetTagHelper
      ASSETS_DIR = "public"
      JAVASCRIPTS_DIR = "#{ASSETS_DIR}/javascripts"
      STYLESHEETS_DIR = "#{ASSETS_DIR}/stylesheets"
    end
  end
end
