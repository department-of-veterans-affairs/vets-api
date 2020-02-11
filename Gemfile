# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.5.7'

# Modules
gem 'appeals_api', path: 'modules/appeals_api'
gem 'claims_api', path: 'modules/claims_api'
gem 'openid_auth', path: 'modules/openid_auth'
gem 'va_facilities', path: 'modules/va_facilities'
gem 'va_forms', path: 'modules/va_forms'
gem 'vaos', path: 'modules/vaos'
gem 'vba_documents', path: 'modules/vba_documents'
gem 'veteran', path: 'modules/veteran'
gem 'veteran_confirmation', path: 'modules/veteran_confirmation'
gem 'veteran_verification', path: 'modules/veteran_verification'

# Anchored versions, do not change
gem 'puma', '~> 4.3.1'
gem 'puma-plugin-statsd', '~> 0.1.0'
gem 'rails', '~> 5.2.4'

# Gems with special version/repo needs
gem 'active_model_serializers', '0.10.4' # breaking changed in 0.10.5 relating to .to_json
gem 'carrierwave', '~> 0.11' # TODO: explanation
gem 'sidekiq-scheduler', '~> 3.0' # TODO: explanation

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter', '~> 5.2.2'
gem 'addressable'
gem 'attr_encrypted', '3.1.0'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'breakers'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/department-of-veterans-affairs/connect_vbms.git', branch: 'master', require: 'vbms'
gem 'date_validator'
gem 'dry-struct'
gem 'dry-types'
gem 'faraday'
gem 'faraday_middleware'
gem 'fast_jsonapi'
gem 'fastimage'
gem 'figaro'
gem 'flipper', '~> 0.17.1'
gem 'flipper-active_record', '~> 0.17.1'
gem 'flipper-active_support_cache_store', '~> 0.17.1'
gem 'flipper-ui', '~> 0.17.1'
gem 'foreman'
gem 'govdelivery-tms', '2.8.4', require: 'govdelivery/tms/mail/delivery_method'
gem 'gyoku'
gem 'holidays'
gem 'httpclient'
gem 'ice_nine'
gem 'iconv'
gem 'iso_country_codes'
gem 'json-schema'
gem 'json_schemer'
gem 'jsonapi-parser'
gem 'jwt'
gem 'levenshtein-ffi'
gem 'lighthouse_bgs', git: 'https://github.com/department-of-veterans-affairs/lighthouse-bgs.git', branch: 'master'
gem 'liquid'
gem 'mail', '2.7.1'
gem 'memoist'
gem 'mini_magick', '~> 4.10.1'
gem 'net-sftp'
gem 'newrelic_rpm'
gem 'nokogiri', '~> 1.10', '>= 1.10.4'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'olive_branch'
gem 'origami'
gem 'ox'
gem 'paper_trail'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'prawn'
gem 'pundit'
gem 'rack', git: 'https://github.com/rack/rack.git', ref: 'f690bb71425aa31d7b9b3113829af773950d8ab5'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rails-session_cookie'
gem 'rails_semantic_logger', '~> 4.4'
gem 'redis'
gem 'redis-namespace'
gem 'request_store'
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
  gem 'brakeman', '~> 4.7'
  gem 'bundler-audit'
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'danger'
  gem 'database_cleaner'
  gem 'factory_bot_rails', '> 5'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_curl'
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
  gem 'rubocop-thread_safety'
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
