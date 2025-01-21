source 'https://rubygems.org'

group :default do
  if rack_version = ENV['RACK_VERSION']
    gem 'rack', rack_version
  else
    gem 'rack', '~> 2.2', '< 3.0'
  end
end

group :development do
  gem 'appraisal', '< 1.0', :require => nil
end

gem 'rake', '~> 13.2', :group => :test, :require => nil
gem 'rspec', :group => :test
