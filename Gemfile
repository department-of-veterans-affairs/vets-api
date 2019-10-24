# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.4.5'

# Modules
gem 'appeals_api', path: 'modules/appeals_api'
gem 'claims_api', path: 'modules/claims_api'
gem 'openid_auth', path: 'modules/openid_auth'
gem 'va_facilities', path: 'modules/va_facilities'
gem 'vaos', path: 'modules/vaos'
gem 'vba_documents', path: 'modules/vba_documents'
gem 'veteran', path: 'modules/veteran'
gem 'veteran_verification', path: 'modules/veteran_verification'

# Anchored versions, do not change
gem 'puma', '~> 3.12.0'
gem 'puma-plugin-statsd', git: 'https://github.com/department-of-veterans-affairs/puma-plugin-statsd', branch: 'master'
gem 'rails', '~> 5.2.3'

# Gems with special version/repo needs
gem 'active_model_serializers', '0.10.4' # breaking changed in 0.10.5 relating to .to_json
gem 'carrierwave', '~> 0.11' # TODO: explanation
gem 'sidekiq-scheduler', '~> 2.0' # TODO: explanation

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter', '~> 5.2.2'
gem 'attr_encrypted', '3.1.0'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'breakers'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/department-of-veterans-affairs/connect_vbms.git', branch: 'master'
gem 'date_validator'
gem 'dry-struct'
gem 'dry-types'
gem 'faraday'
gem 'faraday_middleware'
gem 'fast_jsonapi'
gem 'fastimage'
gem 'figaro'
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-active_support_cache_store'
gem 'flipper-ui'
gem 'lighthouse_bgs', git: 'https://github.com/department-of-veterans-affairs/lighthouse-bgs.git', branch: 'master'

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
gem 'mini_magick', '~> 4.9.4'
gem 'net-sftp'
gem 'nokogiri', '~> 1.10', '>= 1.10.4'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'olive_branch'
gem 'origami'
gem 'ox'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'prawn'
gem 'pundit'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rails-session_cookie'
gem 'rails_semantic_logger', '~> 4.4'
gem 'redis'
gem 'redis-namespace'
gem 'restforce'
gem 'rgeo-geojson'
gem 'ruby-saml'
gem 'rubyzip', '>= 1.3.0'
gem 'savon'
gem 'sentry-raven', '2.9.0' # don't change gem version unless sentry server is also upgraded
gem 'shrine'
gem 'sidekiq-instrument'
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
  gem 'benchmark-ips'
  gem 'guard-rubocop'
  gem 'seedbank'
  gem 'socksify'
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doesn't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', platforms: :ruby
end

group :test do
  gem 'apivore'
  gem 'awrence'
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
  gem 'danger'
  gem 'database_cleaner'
  gem 'factory_bot_rails', '> 5'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_curl'
  gem 'foreman'
  gem 'fuubar'
  gem 'guard-rspec', '~> 4.7'
  gem 'overcommit'
  gem 'pry-byebug'
  gem 'rack-test', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rainbow' # Used to colorize output for rake tasks
  gem 'rspec-rails', '~> 3.5'
  gem 'rubocop', require: false
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'sidekiq', '~> 4.2'
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
