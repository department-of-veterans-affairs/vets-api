# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.3.3'

# Modules
path 'modules' do
  gem 'accredited_representative_portal'
  gem 'appeals_api'
  gem 'apps_api'
  gem 'ask_va_api'
  gem 'avs'
  gem 'check_in'
  gem 'claims_api'
  gem 'covid_research'
  gem 'covid_vaccine'
  gem 'debts_api'
  gem 'dhp_connected_devices'
  gem 'facilities_api'
  gem 'health_quest'
  gem 'income_limits'
  gem 'ivc_champva'
  gem 'meb_api'
  gem 'mobile'
  gem 'mocked_authentication'
  gem 'my_health'
  gem 'pensions'
  gem 'representation_management'
  gem 'simple_forms_api'
  gem 'test_user_dashboard'
  gem 'travel_pay'
  gem 'va_forms'
  gem 'va_notify'
  gem 'vaos'
  gem 'vba_documents'
  gem 'veteran'
  gem 'veteran_confirmation'
  gem 'vye'
end

gem 'rails', '~> 7.1.3'

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter'
gem 'addressable'
gem 'aws-sdk-kms'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'bgs_ext', git: 'https://github.com/department-of-veterans-affairs/bgs-ext.git', require: 'bgs', ref: '350e45ae69'
gem 'blueprinter'
gem 'bootsnap', require: false
gem 'breakers'
gem 'carrierwave'
gem 'carrierwave-aws'
gem 'clamav-client', require: 'clamav/client'
gem 'combine_pdf'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/adhocteam/connect_vbms', tag: 'v2.1.1', require: 'vbms'
gem 'csv'
gem 'date_validator'
gem 'ddtrace'
gem 'dogstatsd-ruby', '5.6.1'
gem 'dry-struct'
gem 'dry-types'
gem 'ethon', '>=0.13.0'
gem 'faraday', '~> 2.10'
gem 'faraday-follow_redirects'
gem 'faraday-httpclient'
gem 'faraday-multipart'
gem 'faraday-retry'
gem 'faraday-typhoeus'
gem 'fastimage'
gem 'fhir_client', git: 'https://github.com/department-of-veterans-affairs/fhir_client.git', tag: 'v6.0.0'
gem 'fitbit_api'
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-active_support_cache_store'
gem 'flipper-ui'
gem 'foreman'
gem 'google-api-client'
gem 'google-apis-core'
gem 'google-apis-generator'
gem 'googleauth'
gem 'google-protobuf' # For Datadog Profiling
gem 'govdelivery-tms', git: 'https://github.com/department-of-veterans-affairs/govdelivery-tms-ruby.git', tag: 'v4.0.0', require: 'govdelivery/tms/mail/delivery_method'
gem 'gyoku'
gem 'hexapdf'
gem 'holidays'
gem 'httpclient' # for lib/evss/base_service.rb
gem 'ice_nine'
gem 'iso_country_codes'
gem 'json'
gem 'jsonapi-parser'
gem 'jsonapi-serializer'
gem 'json-schema'
gem 'json_schemer'
gem 'jwe'
gem 'jwt'
gem 'kms_encrypted'
gem 'liquid'
gem 'lockbox'
gem 'mail'
gem 'memoist'
gem 'mimemagic'
gem 'mini_magick'
gem 'net-sftp'
gem 'nkf'
gem 'nokogiri'
gem 'notifications-ruby-client'
gem 'octokit'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'okcomputer'
gem 'olive_branch'
gem 'operating_hours'
gem 'ox'
gem 'parallel'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'pg_query'
gem 'pg_search'
gem 'pkce_challenge'
gem 'prawn'
gem 'prawn-markup'
gem 'prawn-table'
gem 'puma'
gem 'pundit'
gem 'rack'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rack-timeout', require: 'rack/timeout/base'
gem 'rails_semantic_logger'
gem 'rails-session_cookie'
gem 'redis'
gem 'redis-namespace'
gem 'request_store'
gem 'restforce'
gem 'rgeo-geojson'
gem 'roo'
gem 'rswag-ui'
gem 'rtesseract'
gem 'ruby-saml'
gem 'rubyzip'
gem 'savon'
gem 'sentry-ruby'
gem 'shrine'
gem 'sign_in_service'
gem 'slack-notify'
gem 'socksify'
gem 'staccato'
gem 'statsd-instrument'
gem 'strong_migrations'
gem 'swagger-blocks'
# Include the IANA Time Zone Database on Windows, where Windows doesn't ship with a timezone database.
# POSIX systems should have this already, so we're not going to bring it in on other platforms
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
gem 'utf8-cleaner'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'virtus'
gem 'warden-github'
gem 'will_paginate'
gem 'with_advisory_lock'

group :development, :production do
  # This needs to be required as early as possible in the initialization
  # process because it starts collecting data on 'require'.
  # Only require this in development and production to avoid slowing down tests.
  gem 'coverband'
end

group :development do
  gem 'guard-rubocop'
  gem 'seedbank'
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', platforms: :ruby
end

group :test do
  gem 'apivore', git: 'https://github.com/department-of-veterans-affairs/apivore', tag: 'v2.0.0.vsp'
  gem 'committee-rails'
  gem 'mock_redis'
  gem 'pdf-inspector'
  gem 'rspec_junit_formatter'
  gem 'rspec-retry'
  gem 'rspec-sidekiq'
  gem 'rubocop-junit-formatter'
  gem 'rufus-scheduler'
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'super_diff'
  gem 'vcr'
  gem 'webrick'
end

group :development, :test do
  gem 'awesome_print' # Pretty print your Ruby objects in full color and with proper indentation
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'danger'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'faker'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_curl'
  gem 'fuubar'
  gem 'guard-rspec'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'rack-test', '2.1.0', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rainbow' # Used to colorize output for rake tasks
  gem 'rspec-instrumentation-matcher'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rswag-specs'
  gem 'rubocop', require: false
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'rubocop-thread_safety'
  gem 'sidekiq', '~> 7.2.0'
  gem 'timecop'
  gem 'webmock'
  gem 'yard'
end

# sidekiq enterprise requires a license key to download. In many cases, basic sidekiq is enough for local development
if (Bundler::Settings.new(Bundler.app_config_path)['enterprise.contribsys.com'].nil? ||
    Bundler::Settings.new(Bundler.app_config_path)['enterprise.contribsys.com']&.empty?) &&
   ENV.fetch('BUNDLE_ENTERPRISE__CONTRIBSYS__COM', '').empty? && ENV.keys.grep(/DEPENDABOT/).empty?
  Bundler.ui.warn 'No credentials found to install Sidekiq Enterprise. This is fine for local development but you may not check in this Gemfile.lock with any Sidekiq gems removed. The README file in this directory contains more information.'
else
  source 'https://enterprise.contribsys.com/' do
    gem 'sidekiq-ent'
    gem 'sidekiq-pro'
  end
end
