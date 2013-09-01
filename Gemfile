source "https://rubygems.org"

if rack_version = ENV['RACK_VERSION']
  gem 'rack', rack_version
else
  gem 'rack'
end

gem "appraisal"

gem 'rake', :group => :test
gem 'rspec', '~> 2.13.0', :group => :test
gem 'jruby-openssl', '>= 0.8.2', :group => :test
