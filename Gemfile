source "https://rubygems.org"

if rack_version = ENV['RACK_VERSION']
  gem 'rack', rack_version
else
  gem 'rack'
end

gem "appraisal"

gem 'rake', :group => :test
gem 'rspec', '~> 2.11', :group => :test
gem 'jruby-openssl', :group => :test
