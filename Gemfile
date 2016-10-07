source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.7.1'
gem "puma", "~> 2.16.0"
gem 'ruby-saml', '~> 1.3.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc
#redis and redis-namespace for session and mvi persistence
gem 'redis'
gem 'redis-namespace'
#virtus for attribute type coercion
gem 'virtus'
#emphasize this is an api only app
gem 'rails-api'
gem 'figaro'
gem 'pg'
gem 'json-schema'
gem 'active_model_serializers', '~> 0.10.0'
gem 'will_paginate'
gem 'faraday'
gem 'faraday_middleware'
gem 'httpclient'
gem 'attr_encrypted'
gem 'olive_branch'
gem 'ox', '~> 2.4'
gem 'savon', '~> 2.0'
gem 'sidekiq'
gem 'whenever', require: false
gem 'multi_json'
gem 'rack-cors', :require => 'rack/cors'
gem 'net-sftp'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', ref: '93185f9adbc97bd9ada9ba1f0188848b2bbdb5f6'

# Amazon Linux's system `json` gem causes conflicts, but
# `multi_json` will prefer `oj` if installed, so include it here.
gem 'oj'

gem 'geoservices'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: :ruby

  # Used to colorize output for rake tasks
  gem "rainbow"

  # Linters
  gem 'rubocop', '~> 0.42.0', require: false

  # Security scanners
  gem 'brakeman'
  gem 'bundler-audit'

  # Testing tools
  gem 'rspec-rails', '~> 3.5'
  gem 'guard-rspec', '~> 4.7'
  gem 'pry-nav'
  gem 'factory_girl_rails'

  gem 'foreman'
end

group :test do
  gem 'simplecov', '~> 0.11', require: false
  gem 'webmock'
  gem 'fakeredis'
  gem 'timecop'
  gem 'vcr'
  gem 'awrence'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0', platforms: :ruby

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring', platforms: :ruby
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doens't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
  gem 'guard-rubocop'
end
