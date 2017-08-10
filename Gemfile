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
gem 'config'
gem 'pg'
gem 'json-schema'
gem 'active_model_serializers'
gem 'will_paginate'
gem 'sentry-raven'            # Sentry integration.
gem 'faraday'
gem 'faraday_middleware'
gem 'httpclient'
gem 'attr_encrypted'
gem 'olive_branch'
gem 'ox'
gem 'savon'
gem 'gyoku'
gem 'require_all'

# background processing and workflow
gem 'sidekiq'
gem 'sidekiq-unique-jobs'
gem 'sidekiq-scheduler', '~> 2.0'
gem 'sidekiq-instrument'
gem 'sidekiq-rate-limiter'
gem 'shrine'
gem 'fastimage'

gem 'carrierwave-aws'
gem 'carrierwave', '~> 0.11'
gem 'typhoeus'

gem 'rack-cors', :require => 'rack/cors'
gem 'net-sftp'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'breakers'
gem 'govdelivery-tms', require: 'govdelivery/tms/mail/delivery_method'
gem 'statsd-instrument'
gem 'memoist'
gem 'date_validator'
gem 'nokogiri'
gem 'swagger-blocks'
gem 'aasm'

# Amazon Linux's system `json` gem causes conflicts, but
# `multi_json` will prefer `oj` if installed, so include it here.
gem 'oj'

gem 'octokit'

gem 'holidays'
gem 'iconv'
gem 'ice_nine'
gem 'pdf-reader'
gem 'aws-sdk'
gem 'mini_magick'
gem 'pdf-forms'
gem 'clam_scan'
gem 'prawn'
gem 'combine_pdf'

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
  gem 'overcommit'
  # This middleware logs your HTTP requests as CURL compatible commands so you can share the calls with downstream
  # assists in debugging
  gem 'faraday_curl'
end

group :test do
  gem 'apivore'
  gem 'faker'
  gem 'faker-medical'
  gem 'simplecov', require: false
  gem 'webmock'
  gem 'fakeredis'
  gem 'timecop'
  gem 'vcr'
  gem 'awrence'
  gem 'climate_control'
  gem 'shrine-memory'
  gem 'pdf-inspector'
  gem 'rspec_junit_formatter'
  gem 'rubocop-junit-formatter'
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
