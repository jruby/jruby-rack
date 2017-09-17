source "https://rubygems.org"

group :default do
  if rack_version = ENV['RACK_VERSION']
    gem 'rack', rack_version
  else
    gem 'rack', '~> 1.6.8'
  end
end

group :development do
  gem 'appraisal', :require => nil
end

gem 'rake', '~> 10.4.2', :group => :test, :require => nil
gem 'rspec', '~> 2.14.1', :group => :test
gem 'jruby-openssl', '~> 0.9.20', :group => :test
