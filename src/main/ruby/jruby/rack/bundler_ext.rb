#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Bundler
  # ZOMGHAX: Ignore errors coming out of mkdir_p for compatibility
  # with Bundler <= 1.0.10, see:
  # https://github.com/carlhuda/bundler/pull/1033
  # https://github.com/nicksieger/bundler/commit/df33aae
  module FileUtils
    def self.mkdir_p(*args)
      ::FileUtils.mkdir_p(*args) rescue nil
    end

    def self.method_missing(*args, &block)
      ::FileUtils.send(*args, &block)
    end
  end
end
