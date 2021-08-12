# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 2.6.6'

# temp fix for security vulnerability, hopefulle we can remove this line with the next rails patch
# https://blog.jcoglan.com/2020/06/02/redos-vulnerability-in-websocket-extensions/
gem 'websocket-extensions', '>= 0.1.5'

# Modules
path 'modules' do
  gem 'appeals_api'
  gem 'apps_api'
  gem 'check_in'
  gem 'claims_api'
  gem 'covid_research'
  gem 'covid_vaccine'
  gem 'facilities_api'
  gem 'health_quest'
  gem 'identity'
  gem 'mobile'
  gem 'openid_auth'
  gem 'test_user_dashboard'
  gem 'va_forms'
  gem 'vaos'
  gem 'vba_documents'
  gem 'veteran'
  gem 'veteran_confirmation'
  gem 'veteran_verification'
end
# End Modules

# needed for PGHero performance dashboard
gem 'sass-rails', '>= 6'

# Anchored versions, do not change
gem 'puma', '~> 5.4.0'
gem 'puma-plugin-statsd', '~> 2.0.0'
gem 'rails', '~> 6.1.3'

# Gems with special version/repo needs
gem 'active_model_serializers', git: 'https://github.com/department-of-veterans-affairs/active_model_serializers', branch: 'master'
gem 'sidekiq-scheduler', '~> 3.1' # TODO: explanation

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter'
gem 'addressable'
gem 'attr_encrypted', '3.1.0'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'bgs_ext', git: 'https://github.com/department-of-veterans-affairs/bgs-ext.git', require: 'bgs'
gem 'blueprinter'
gem 'breakers'
gem 'bootsnap', require: false
gem 'carrierwave'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'combine_pdf'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/department-of-veterans-affairs/connect_vbms.git', branch: 'master', require: 'vbms'
gem 'date_validator'
gem 'dry-struct'
gem 'dry-types'
gem 'faraday'
gem 'faraday_middleware'
gem 'fast_jsonapi'
gem 'fastimage'
gem 'fhir_client', '~> 4.0.6'
gem 'flipper', '~> 0.21.0'
gem 'flipper-active_record', '~> 0.21.0'
gem 'flipper-active_support_cache_store', '~> 0.21.0'
gem 'flipper-ui', '~> 0.21.0'
gem 'foreman'
gem 'google-api-client'
gem 'google-apis-core'
gem 'google-apis-generator'
gem 'googleauth'
gem 'govdelivery-tms', '2.8.4', require: 'govdelivery/tms/mail/delivery_method'
gem 'gyoku'
gem 'holidays'
gem 'httpclient'
gem 'ice_nine'
gem 'iso_country_codes'
gem 'json', '>= 2.3.0'
gem 'json-schema'
gem 'json_schemer'
gem 'jsonapi-parser'
gem 'jwt'
gem 'levenshtein-ffi'
gem 'liquid'
gem 'mail', '2.7.1'
gem 'memoist'
gem 'mimemagic', '~> 0.4.3'
gem 'mini_magick', '~> 4.11.0'
gem 'net-sftp'
gem 'nokogiri', '~> 1.12'
gem 'notifications-ruby-client', '~> 5.3'
gem 'octokit'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'okcomputer'
gem 'olive_branch'
gem 'operating_hours'
gem 'ox'
gem 'paper_trail'
gem 'parallel'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'pg_query', '>= 0.9.0'
gem 'pg_search'
gem 'pghero'
gem 'prawn'
gem 'prawn-table'
gem 'pundit'
gem 'rack'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rails-session_cookie'
gem 'rails_semantic_logger', '~> 4.6'
gem 'redis'
gem 'redis-namespace'
gem 'request_store'
gem 'restforce'
gem 'rgeo-geojson'
gem 'rswag-ui'
gem 'ruby-saml'
gem 'rubyzip', '>= 1.3.0'
gem 'savon'
gem 'sentry-raven'
gem 'shrine'
gem 'slack-notify'
gem 'staccato'
gem 'statsd-instrument', '~> 3.1.0'
gem 'strong_migrations'
gem 'swagger-blocks'
gem 'typhoeus'
gem 'utf8-cleaner'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'virtus'
gem 'warden-github'
gem 'will_paginate'
gem 'with_advisory_lock'

group :development do
  gem 'guard-rubocop'
  gem 'seedbank'
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doesn't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'debase'
  gem 'ruby-debug-ide', git: 'https://github.com/corgibytes/ruby-debug-ide', branch: 'feature-add-fixed-port-range'
  gem 'web-console', platforms: :ruby
end

group :test do
  gem 'apivore', git: 'https://github.com/department-of-veterans-affairs/apivore', branch: 'master'
  gem 'fakeredis'
  gem 'pact', require: false
  gem 'pact-mock_service', require: false
  gem 'pdf-inspector'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'rubocop-junit-formatter'
  gem 'simplecov', require: false
  gem 'super_diff'
  gem 'vcr'
  gem 'webrick', '>= 1.6.1'
end

group :development, :test do
  gem 'awesome_print', '~> 1.9' # Pretty print your Ruby objects in full color and with proper indentation
  gem 'brakeman', '~> 5.0'
  gem 'bundler-audit'
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'danger'
  gem 'database_cleaner'
  gem 'factory_bot_rails', '> 5'
  gem 'faker'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_adapter_socks'
  gem 'faraday_curl'
  gem 'fuubar'
  gem 'guard-rspec', '~> 4.7'
  gem 'overcommit'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'rack-test', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rainbow' # Used to colorize output for rake tasks
  gem 'rspec-instrumentation-matcher'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rswag-specs'
  gem 'rubocop', require: false
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-thread_safety'
  gem 'sidekiq', '< 7'
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
