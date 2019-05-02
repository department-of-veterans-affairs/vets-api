# frozen_string_literal: true

source 'https://rubygems.org'

gem 'appeals_api', path: 'modules/appeals_api'
gem 'claims_api', path: 'modules/claims_api'
gem 'openid_auth', path: 'modules/openid_auth'
gem 'va_facilities', path: 'modules/va_facilities'
gem 'vba_documents', path: 'modules/vba_documents'
gem 'veteran', path: 'modules/veteran'
gem 'veteran_verification', path: 'modules/veteran_verification'

# Anchored versions, do not change
gem 'puma', '~> 3.12.0'
gem 'puma-plugin-statsd', git: 'https://github.com/department-of-veterans-affairs/puma-plugin-statsd', branch: 'master'
gem 'rails', '~> 5.1.6.2'

# Gems with special version/repo needs
gem 'active_model_serializers', '0.10.4' # breaking changed in 0.10.5 relating to .to_json
gem 'carrierwave', '~> 0.11' # TODO: explanation
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc # TODO: explanation
gem 'sidekiq-scheduler', '~> 2.0' # TODO: explanation

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter', '~> 5.2.2'
gem 'attr_encrypted', '3.1.0'
gem 'aws-sdk', '~> 3'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'breakers'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/department-of-veterans-affairs/connect_vbms.git', branch: 'master'
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
gem 'jsonapi-parser'
gem 'jwt'
gem 'levenshtein-ffi'
gem 'liquid'
gem 'mail', '2.6.6'
gem 'memoist'
gem 'mini_magick'
gem 'net-sftp'
gem 'nokogiri', '~> 1.10', '>= 1.10.3'
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
gem 'rails_semantic_logger', '~> 4.4'
gem 'redis'
gem 'redis-namespace'
gem 'restforce'
gem 'ruby-saml'
gem 'savon'
gem 'sentry-raven', '2.7.4' # don't change gem version unless sentry server is also upgraded
gem 'shrine'
gem 'sidekiq-instrument'
gem 'sidekiq-unique-jobs'
gem 'staccato'
gem 'statsd-instrument'
gem 'swagger-blocks'
gem 'typhoeus'
gem 'upsert'
gem 'utf8-cleaner'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'virtus'
gem 'will_paginate'
gem 'zero_downtime_migrations'

group :development do
  gem 'guard-rubocop'
  gem 'seedbank'
  gem 'socksify'
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doesn't ship with a timezone database.
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
  gem 'rails-session_cookie' # because request and integration specs dont allow for setting session cookie easily
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
  gem 'pry-byebug'
  gem 'rainbow' # Used to colorize output for rake tasks
  # TODO: switch to a version number once that version is released
  gem 'factory_bot', git: 'https://github.com/thoughtbot/factory_bot', ref: '50eeb67241ea78a6b138eea694a2a25413052f49'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_curl'
  gem 'foreman'
  gem 'guard-rspec', '~> 4.7'
  gem 'overcommit'
  gem 'rack-test', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rspec-rails', '~> 3.5'
  gem 'rubocop', '~> 0.52.1', require: false
  gem 'sidekiq'
  gem 'timecop'
  gem 'webmock'
  gem 'yard'
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
