# frozen_string_literal: true

source 'https://rubygems.org'

gem 'appeals_api', path: 'modules/appeals_api'
gem 'vba_documents', path: 'modules/vba_documents'
gem 'veteran_verification', path: 'modules/veteran_verification'

# Anchored versions, do not change
gem 'puma', '~> 2.16.0'
gem 'rails', '4.2.7.1'

# Gems with special version/repo needs
gem 'active_model_serializers', '0.10.4' # breaking changed in 0.10.5 relating to .to_json
gem 'carrierwave', '~> 0.11' # TODO: explanation
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc # TODO: explanation
gem 'sidekiq-scheduler', '~> 2.0' # TODO: explanation

gem 'aasm'
gem 'attr_encrypted'
gem 'aws-sdk', '~> 3'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'breakers'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'config'
gem 'date_validator'
gem 'faraday'
gem 'faraday_middleware'
gem 'fastimage'
gem 'figaro'
gem 'govdelivery-tms', '2.8.4', require: 'govdelivery/tms/mail/delivery_method'
gem 'gyoku'
gem 'holidays'
gem 'httpclient'
gem 'ice_nine'
gem 'iconv'
gem 'iso_country_codes'
gem 'json-schema'
gem 'jwt'
gem 'levenshtein-ffi'
gem 'liquid'
gem 'memoist'
gem 'mini_magick'
gem 'net-sftp'
gem 'nokogiri'
gem 'octokit'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'olive_branch'
gem 'ox'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'prawn'
gem 'pundit'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rails-api'
gem 'rails_semantic_logger', '~> 4.2'
gem 'redis'
gem 'redis-namespace'
gem 'require_all'
gem 'restforce'
gem 'ruby-saml'
gem 'savon'
gem 'sentry-raven'
gem 'shrine'
gem 'sidekiq-instrument'
gem 'sidekiq-unique-jobs'
gem 'staccato'
gem 'statsd-instrument'
gem 'swagger-blocks'
gem 'typhoeus'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'virtus'
gem 'will_paginate'
gem 'zero_downtime_migrations'

group :development do
  gem 'guard-rubocop'
  gem 'socksify'
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doens't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0', platforms: :ruby
end

group :test do
  gem 'apivore'
  gem 'awrence'
  gem 'climate_control'
  gem 'faker'
  gem 'faker-medical'
  gem 'fakeredis'
  gem 'pdf-inspector'
  gem 'rspec_junit_formatter'
  gem 'rubocop-junit-formatter'
  gem 'shrine-memory'
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webrick'
end

group :development, :test do
  gem 'awesome_print', '~> 1.8' # Pretty print your Ruby objects in full color and with proper indentation
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'factory_bot_rails'
  gem 'rainbow' # Used to colorize output for rake tasks
  # TODO: switch to a version number once that version is released
  gem 'factory_bot', git: 'https://github.com/thoughtbot/factory_bot', ref: '50eeb67241ea78a6b138eea694a2a25413052f49'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_curl'
  gem 'foreman'
  gem 'guard-rspec', '~> 4.7'
  gem 'overcommit'
  gem 'pry-nav'
  gem 'rack-test', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rspec-rails', '~> 3.5'
  gem 'rubocop', '~> 0.52.1', require: false
  gem 'sidekiq'
  gem 'timecop'
  gem 'webmock'
end

group :production do
  # sidekiq enterprise requires a license key to download but is only required in production.
  # for local dev environments, regular sidekiq works fine
  unless ENV['EXCLUDE_SIDEKIQ_ENTERPRISE'] == 'true'
    source 'https://enterprise.contribsys.com/' do
      gem 'sidekiq-ent'
      gem 'sidekiq-pro'
    end
  end
end
