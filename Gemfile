source 'https://rubygems.org'

# Core Components - These should have pessimistic versioning
gem 'rails', '4.2.7.1'
gem "puma", "~> 2.16.0"
gem 'ruby-saml', '~> 1.3.0'
gem 'active_model_serializers', '~> 0.10.0'
gem 'redis', '~> 3.2'

# Other
gem 'pg'                             # Postgres ActiveRecord Adapter
gem 'redis-namespace'
gem 'rails-api'                      # emphasize this is an api only app
gem 'rack-cors', :require => 'rack/cors'

# Model Helpers
gem 'virtus'
gem 'attr_encrypted'
gem 'json-schema'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'will_paginate', '~> 3.1.0'

# External Requests and Parsing
gem 'govdelivery-tms', require: 'govdelivery/tms/mail/delivery_method'
gem 'net-sftp'
gem 'faraday'
gem 'faraday_middleware'
gem 'httpclient'
gem 'typhoeus'
gem 'breakers'
gem 'multi_json'              # THIS DEPENDENCY SHOULD BE REMOVED, it's meant for gems, just use OJ instead
gem 'oj'                      # Faster JSON parser, will be used automatically when using MultiJson
gem 'ox', '~> 2.4'
gem 'savon', '~> 2.0'
gem 'olive_branch'

# Queing and Image Processing
gem 'sidekiq'
gem 'sidekiq-unique-jobs'
gem 'sidekiq-scheduler', '~> 2.0'
gem 'sidekiq-instrument'
gem 'carrierwave-aws'
gem 'carrierwave', '~> 0.11'

# Errors and Error Reporting
gem 'figaro'
gem 'sentry-raven'                  # Sentry integration. SENTRY_DSN provided in ENV
gem 'statsd-instrument'

# Documentation
gem 'sdoc', '~> 0.4.0', group: :doc  # bundle exec rake doc:rails generates the API under doc/api.

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

  # This middleware logs your HTTP requests as CURL compatible commands so you can share the calls with downstream
  # assists in debugging
  gem 'faraday_curl'
end

group :test do
  gem 'faker'
  gem 'simplecov', '~> 0.11', require: false
  gem 'webmock'
  gem 'fakeredis'
  gem 'timecop'
  gem 'vcr'
  gem 'awrence'
  gem 'climate_control', '0.0.3'
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
