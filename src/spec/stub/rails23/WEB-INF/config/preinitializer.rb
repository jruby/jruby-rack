begin
  require 'bundler'
rescue LoadError => e
  require('rubygems') && retry
  puts "Could not load the bundler gem. Install it with `gem install bundler`."
  raise e
end

ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
Bundler.setup