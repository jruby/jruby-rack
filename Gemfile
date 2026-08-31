source 'https://rubygems.org'

group :default do
  if (rack_version = ENV['RACK_VERSION'])
    gem 'rack', rack_version
  else
    gem 'rack', '~> 3.2.7'
  end
end

group :development do
  gem 'appraisal', :require => nil
  gem 'rexml'
end

group :test do
  gem 'rake', '~> 13.4', :require => nil
  gem 'rspec'

  gem 'logger' # Required for stubbing Rails' active_support/logger
end
