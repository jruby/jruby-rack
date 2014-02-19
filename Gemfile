source "https://rubygems.org"

group :development do
  if rack_version = ENV['RACK_VERSION']
    gem 'rack', rack_version
  else
    gem 'rack', '~> 1.4.5'
  end
end

gem 'appraisal', :require => nil

gem 'rake', :group => :test, :require => nil
gem 'rspec', '~> 2.14.1', :group => :test
gem 'jruby-openssl', :group => :test if JRUBY_VERSION < '1.7.0'
