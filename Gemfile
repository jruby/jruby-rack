source 'https://rubygems.org'

group :default do
  if rack_version = ENV['RACK_VERSION']
    gem 'rack', rack_version
  else
    gem 'rack', '~> 2.2.23'
  end
end

group :development do
  gem 'appraisal', :require => nil
end

gem 'rake', '~> 13.4', :group => :test, :require => nil
gem 'rspec', :group => :test
