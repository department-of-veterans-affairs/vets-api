source 'https://rubygems.org'
gem 'rails', '4.2.7.1'
gem "puma", "~> 2.16.0"

gem 'ruby-saml', '~> 1.3.0'
gem 'sdoc', '~> 0.4.0', group: :doc # bundle exec rake doc:rails generates the API under doc/api.
gem 'redis'
gem 'redis-namespace'
gem 'virtus'
gem 'rails-api'
gem 'figaro'
gem 'config'
gem 'pg'
gem 'json-schema'
gem 'active_model_serializers'
gem 'will_paginate'
gem 'sentry-raven'
gem 'faraday'
gem 'faraday_middleware'
gem 'httpclient'
gem 'attr_encrypted'
gem 'olive_branch'
gem 'ox'
gem 'savon'
gem 'gyoku'
gem 'require_all'
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
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
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
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "rainbow" # Used to colorize output for rake tasks
  gem 'rubocop', '~> 0.42.0', require: false
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'rspec-rails', '~> 3.5'
  gem 'guard-rspec', '~> 4.7'
  gem 'pry-nav'
  gem 'factory_girl_rails'
  gem 'foreman'
  gem 'overcommit'
  gem 'faraday_curl'
  gem 'rack-vcr'
  gem 'webmock'
  gem 'timecop'
end

group :test do
  gem 'apivore'
  gem 'faker'
  gem 'faker-medical'
  gem 'simplecov', require: false
  gem 'fakeredis'
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
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doens't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
  gem 'guard-rubocop'
end
